defmodule ExBoxPacker.Packer do
  @moduledoc """
  Top-level multi-box packer with catalog box selection. Faithful port of BoxPacker's
  `Packer::doBasicPacking` + `getBoxList`.

  Greedy loop: sort items (largest first) and boxes (smallest first); while items remain,
  trial-pack each candidate box (boxes that can hold *all* remaining items first) with
  `VolumePacker`, pick the best packed box per the `PackedBoxSorter`, remove those items,
  and repeat.

  Options: `:packed_box_sorter` (module, default `DefaultPackedBoxSorter`),
  `:strict_ordering?` (default `false`). Boxes implementing `ExBoxPacker.LimitedSupplyBox`
  are only used up to their available quantity. Items implementing `ExBoxPacker.LinkedItem`
  are kept together as linked-item groups (a linked group is never split across boxes).

  `:timeout` (number of SECONDS, default `nil` = unbounded) bounds packing time. When set,
  `ExBoxPacker.TimeoutError` is raised (it propagates from `pack/3`, `pack!/3` and
  `pack_all_possible/3`) once the deadline is exceeded during the per-box trial-packing loop.
  Port of BoxPacker's `TimeoutChecker`/`DefaultTimeoutChecker`.
  """

  alias ExBoxPacker.{Box, Item, LimitedSupplyBox, NoBoxesAvailableError, TimeoutError}

  alias ExBoxPacker.Engine.{
    BoxList,
    Cache,
    ItemList,
    LinkedItemGroupEnforcer,
    VolumePacker,
    WeightRedistributor
  }

  alias ExBoxPacker.Broadcast
  alias ExBoxPacker.Result.{PackedBox, PackedBoxList, PackedItemList}
  alias ExBoxPacker.Sorting.DefaultPackedBoxSorter

  @doc "Pack `items` into the fewest `boxes`. Returns `{:ok, PackedBoxList}` or `{:error, NoBoxesAvailableError}`."
  @spec pack([Box.t()], [Item.t()], keyword()) ::
          {:ok, PackedBoxList.t()} | {:error, Exception.t()}
  def pack(boxes, items, opts \\ []) do
    Cache.with_cache(fn ->
      {packed, leftover} = do_pack(boxes, items, opts)

      case leftover do
        [] -> {:ok, maybe_redistribute(packed, boxes, opts)}
        _ -> {:error, NoBoxesAvailableError.exception(leftover)}
      end
    end)
  end

  defp maybe_redistribute(packed, boxes, opts) do
    strict? = Keyword.get(opts, :strict_ordering?, false)
    max_balance = Keyword.get(opts, :max_boxes_to_balance_weight, 12)
    sorter = Keyword.get(opts, :packed_box_sorter, DefaultPackedBoxSorter)
    count = PackedBoxList.count(packed)

    # NOTE: WeightRedistributor is quantity-unaware — it repacks via `pack_all_possible`
    # treating boxes as unlimited. A quantity-aware repack is a future refinement.

    if not strict? and count > 1 and count <= max_balance do
      WeightRedistributor.redistribute(packed, BoxList.sort(boxes), sorter)
    else
      packed
    end
  end

  @doc "Like `pack/3` but returns the `PackedBoxList` directly or raises `NoBoxesAvailableError`."
  @spec pack!([Box.t()], [Item.t()], keyword()) :: PackedBoxList.t()
  def pack!(boxes, items, opts \\ []) do
    case pack(boxes, items, opts) do
      {:ok, packed} -> packed
      {:error, error} -> raise error
    end
  end

  @doc "Pack as much as possible; never errors. Returns `{PackedBoxList, leftover_items}`."
  @spec pack_all_possible([Box.t()], [Item.t()], keyword()) :: {PackedBoxList.t(), [Item.t()]}
  def pack_all_possible(boxes, items, opts \\ []) do
    Cache.with_cache(fn -> do_pack(boxes, items, opts) end)
  end

  defp do_pack(boxes, items, opts) do
    sorter = Keyword.get(opts, :packed_box_sorter, DefaultPackedBoxSorter)
    strict? = Keyword.get(opts, :strict_ordering?, false)
    enforce_single? = Keyword.get(opts, :enforce_single_box?, false)
    topic = Keyword.get(opts, :broadcast_topic)
    sorted_items = ItemList.from_items(items)
    sorted_boxes = BoxList.sort(boxes)
    quantities = initial_quantities(boxes)
    timeout_ctx = start_timeout(Keyword.get(opts, :timeout))

    if topic, do: Broadcast.started(topic)

    {packed, leftover} =
      do_basic_packing(
        sorted_boxes,
        sorted_items,
        sorter,
        strict?,
        enforce_single?,
        quantities,
        timeout_ctx,
        topic,
        PackedBoxList.new(sorter)
      )

    if topic, do: Broadcast.done(topic, Broadcast.summary(packed, leftover))

    {packed, leftover}
  end

  # Port of `TimeoutChecker::start` — records a deadline in monotonic ms alongside the
  # configured timeout (in seconds) and start time, or `nil` when no timeout is set.
  defp start_timeout(nil), do: nil

  defp start_timeout(timeout) when is_number(timeout) do
    start_ms = System.monotonic_time(:millisecond)
    %{deadline_ms: start_ms + round(timeout * 1000), timeout: timeout, start_ms: start_ms}
  end

  # Port of `TimeoutChecker::throwOnTimeout` — raises once the deadline is reached.
  defp throw_on_timeout(nil), do: :ok

  defp throw_on_timeout(%{deadline_ms: deadline_ms, timeout: timeout, start_ms: start_ms}) do
    now = System.monotonic_time(:millisecond)

    if now >= deadline_ms do
      raise TimeoutError,
        message: "Exceeded the timeout",
        timeout: timeout,
        spent_time: (now - start_ms) / 1000
    end

    :ok
  end

  # Box quantity available: `LimitedSupplyBox.quantity_available/1` for boxes implementing the
  # protocol, else `:infinity` (unlimited). Port of Packer's `boxQuantitiesAvailable` WeakMap.
  defp initial_quantities(boxes) do
    Map.new(boxes, fn box ->
      # `impl_for/1` and `quantity_available/1` are routed through `apply/3` so the
      # compile-time type checker does not treat this optional extension protocol (only
      # user/test code implements it) as statically unimplemented — which would flag the
      # `else` branch as unreachable. The `impl_for/1` guard and runtime behaviour are
      # identical to direct calls.
      # credo:disable-for-lines:5 Credo.Check.Refactor.Apply
      qty =
        if apply(LimitedSupplyBox, :impl_for, [box]) do
          apply(LimitedSupplyBox, :quantity_available, [box])
        else
          :infinity
        end

      {box, qty}
    end)
  end

  defp do_basic_packing(
         _boxes,
         [],
         _sorter,
         _strict?,
         _enforce_single?,
         _quantities,
         _timeout_ctx,
         _topic,
         acc
       ),
       do: {acc, []}

  defp do_basic_packing(
         boxes,
         items,
         sorter,
         strict?,
         enforce_single?,
         quantities,
         timeout_ctx,
         topic,
         acc
       ) do
    box_list = get_box_list(items, boxes, enforce_single?, quantities)

    case collect_candidates(box_list, items, strict?, timeout_ctx) do
      [] ->
        {acc, items}

      candidates ->
        best = candidates |> Enum.sort(&(sorter.compare(&1, &2) <= 0)) |> hd()
        remaining = subtract_packed(items, best)
        if topic, do: Broadcast.box_packed(topic, best)

        do_basic_packing(
          boxes,
          remaining,
          sorter,
          strict?,
          enforce_single?,
          Map.update!(quantities, best.box, &decrement/1),
          timeout_ctx,
          topic,
          PackedBoxList.insert(acc, best)
        )
    end
  end

  # Trial-pack each box; collect non-empty results; stop early if one packs everything.
  # Faithful to `doBasicPacking`: `throwOnTimeout` is checked at the top of each box iteration.
  defp collect_candidates(box_list, items, strict?, timeout_ctx) do
    total = length(items)

    box_list
    |> Enum.reduce_while([], fn box, acc ->
      throw_on_timeout(timeout_ctx)
      packed = VolumePacker.pack(box, items, strict_ordering?: strict?)
      packed = LinkedItemGroupEnforcer.enforce_constraint(packed, items, strict?)

      case PackedItemList.count(packed.items) do
        0 -> {:cont, acc}
        ^total -> {:halt, [packed | acc]}
        _ -> {:cont, [packed | acc]}
      end
    end)
    |> Enum.reverse()
  end

  # Boxes that can hold ALL remaining items (by volume) first, then the rest — both in the
  # incoming (smallest-first) order. Boxes with no supply left are skipped (port of
  # `getBoxList`'s `boxQuantitiesAvailable[$box] > 0` check).
  defp get_box_list(items, boxes, enforce_single?, quantities) do
    item_volume =
      Enum.reduce(items, 0, fn i, acc -> acc + Item.width(i) * Item.length(i) * Item.depth(i) end)

    available = Enum.filter(boxes, &available?(Map.fetch!(quantities, &1)))

    {preferred, other} =
      Enum.split_with(available, fn box ->
        Box.inner_width(box) * Box.inner_length(box) * Box.inner_depth(box) >= item_volume
      end)

    if enforce_single?, do: preferred, else: preferred ++ other
  end

  defp available?(:infinity), do: true
  defp available?(n), do: n > 0

  defp decrement(:infinity), do: :infinity
  defp decrement(n), do: n - 1

  # O(n) equivalent of `Enum.reduce(packed_items, items, &List.delete(&2, &1))`: build a
  # frequency map of the packed items, then walk `items` once, dropping the first N
  # occurrences of each packed value (N = its count) and keeping the rest in order. This
  # yields the identical survivor list as the repeated first-occurrence `List.delete`.
  defp subtract_packed(items, %PackedBox{items: packed_list}) do
    to_remove = packed_list |> PackedItemList.as_items() |> Enum.frequencies()

    {kept, _} =
      Enum.reduce(items, {[], to_remove}, fn item, {kept, counts} ->
        case counts do
          %{^item => n} when n > 0 -> {kept, Map.put(counts, item, n - 1)}
          _ -> {[item | kept], counts}
        end
      end)

    Enum.reverse(kept)
  end
end

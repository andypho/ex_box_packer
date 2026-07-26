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
  are only used up to their available quantity. Linked items are added in a later milestone.
  """

  alias ExBoxPacker.{Box, Item, LimitedSupplyBox, NoBoxesAvailableError}
  alias ExBoxPacker.Engine.{BoxList, ItemList, VolumePacker, WeightRedistributor}
  alias ExBoxPacker.Result.{PackedBox, PackedBoxList, PackedItemList}
  alias ExBoxPacker.Sorting.DefaultPackedBoxSorter

  @doc "Pack `items` into the fewest `boxes`. Returns `{:ok, PackedBoxList}` or `{:error, NoBoxesAvailableError}`."
  @spec pack([Box.t()], [Item.t()], keyword()) ::
          {:ok, PackedBoxList.t()} | {:error, Exception.t()}
  def pack(boxes, items, opts \\ []) do
    {packed, leftover} = do_pack(boxes, items, opts)

    case leftover do
      [] -> {:ok, maybe_redistribute(packed, boxes, opts)}
      _ -> {:error, NoBoxesAvailableError.exception(leftover)}
    end
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
  def pack_all_possible(boxes, items, opts \\ []), do: do_pack(boxes, items, opts)

  defp do_pack(boxes, items, opts) do
    sorter = Keyword.get(opts, :packed_box_sorter, DefaultPackedBoxSorter)
    strict? = Keyword.get(opts, :strict_ordering?, false)
    enforce_single? = Keyword.get(opts, :enforce_single_box?, false)
    sorted_items = ItemList.from_items(items)
    sorted_boxes = BoxList.sort(boxes)
    quantities = initial_quantities(boxes)

    do_basic_packing(
      sorted_boxes,
      sorted_items,
      sorter,
      strict?,
      enforce_single?,
      quantities,
      PackedBoxList.new(sorter)
    )
  end

  # Box quantity available: `LimitedSupplyBox.quantity_available/1` for boxes implementing the
  # protocol, else `:infinity` (unlimited). Port of Packer's `boxQuantitiesAvailable` WeakMap.
  defp initial_quantities(boxes) do
    Map.new(boxes, fn box ->
      qty =
        if LimitedSupplyBox.impl_for(box),
          do: LimitedSupplyBox.quantity_available(box),
          else: :infinity

      {box, qty}
    end)
  end

  defp do_basic_packing(_boxes, [], _sorter, _strict?, _enforce_single?, _quantities, acc),
    do: {acc, []}

  defp do_basic_packing(boxes, items, sorter, strict?, enforce_single?, quantities, acc) do
    box_list = get_box_list(items, boxes, enforce_single?, quantities)

    case collect_candidates(box_list, items, strict?) do
      [] ->
        {acc, items}

      candidates ->
        best = candidates |> Enum.sort(&(sorter.compare(&1, &2) <= 0)) |> hd()
        remaining = subtract_packed(items, best)

        do_basic_packing(
          boxes,
          remaining,
          sorter,
          strict?,
          enforce_single?,
          Map.update!(quantities, best.box, &decrement/1),
          PackedBoxList.insert(acc, best)
        )
    end
  end

  # Trial-pack each box; collect non-empty results; stop early if one packs everything.
  defp collect_candidates(box_list, items, strict?) do
    total = length(items)

    box_list
    |> Enum.reduce_while([], fn box, acc ->
      packed = VolumePacker.pack(box, items, strict_ordering?: strict?)

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

  defp subtract_packed(items, %PackedBox{items: packed_list}) do
    packed_list
    |> PackedItemList.as_items()
    |> Enum.reduce(items, fn packed_item, acc -> List.delete(acc, packed_item) end)
  end
end

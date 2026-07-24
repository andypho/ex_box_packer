defmodule ExBoxPacker.Packer do
  @moduledoc """
  Top-level multi-box packer with catalog box selection. Faithful port of BoxPacker's
  `Packer::doBasicPacking` + `getBoxList`.

  Greedy loop: sort items (largest first) and boxes (smallest first); while items remain,
  trial-pack each candidate box (boxes that can hold *all* remaining items first) with
  `VolumePacker`, pick the best packed box per the `PackedBoxSorter`, remove those items,
  and repeat.

  Options: `:packed_box_sorter` (module, default `DefaultPackedBoxSorter`),
  `:strict_ordering?` (default `false`). Weight redistribution, limited supply, and linked
  items are added in later milestones.
  """

  alias ExBoxPacker.{Box, Item, NoBoxesAvailableError}
  alias ExBoxPacker.Engine.{BoxList, ItemList, VolumePacker}
  alias ExBoxPacker.Result.{PackedBox, PackedBoxList, PackedItemList}
  alias ExBoxPacker.Sorting.DefaultPackedBoxSorter

  @doc "Pack `items` into the fewest `boxes`. Returns `{:ok, PackedBoxList}` or `{:error, NoBoxesAvailableError}`."
  @spec pack([Box.t()], [Item.t()], keyword()) ::
          {:ok, PackedBoxList.t()} | {:error, Exception.t()}
  def pack(boxes, items, opts \\ []) do
    {packed, leftover} = do_pack(boxes, items, opts)

    case leftover do
      [] -> {:ok, packed}
      _ -> {:error, NoBoxesAvailableError.exception(leftover)}
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
    sorted_items = ItemList.from_items(items)
    sorted_boxes = BoxList.sort(boxes)
    do_basic_packing(sorted_boxes, sorted_items, sorter, strict?, PackedBoxList.new(sorter))
  end

  defp do_basic_packing(_boxes, [], _sorter, _strict?, acc), do: {acc, []}

  defp do_basic_packing(boxes, items, sorter, strict?, acc) do
    case collect_candidates(get_box_list(items, boxes), items, strict?) do
      [] ->
        {acc, items}

      candidates ->
        best = candidates |> Enum.sort(&(sorter.compare(&1, &2) <= 0)) |> hd()
        remaining = subtract_packed(items, best)
        do_basic_packing(boxes, remaining, sorter, strict?, PackedBoxList.insert(acc, best))
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
  # incoming (smallest-first) order.
  defp get_box_list(items, boxes) do
    item_volume =
      Enum.reduce(items, 0, fn i, acc -> acc + Item.width(i) * Item.length(i) * Item.depth(i) end)

    {preferred, other} =
      Enum.split_with(boxes, fn box ->
        Box.inner_width(box) * Box.inner_length(box) * Box.inner_depth(box) >= item_volume
      end)

    preferred ++ other
  end

  defp subtract_packed(items, %PackedBox{items: packed_list}) do
    packed_list
    |> PackedItemList.as_items()
    |> Enum.reduce(items, fn packed_item, acc -> List.delete(acc, packed_item) end)
  end
end

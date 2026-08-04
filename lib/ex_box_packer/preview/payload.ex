defmodule ExBoxPacker.Preview.Payload do
  @moduledoc false
  # Serialisable packing payload for the 3D preview. Shape matches BoxPacker's visualiser:
  #   %{"items" => [[desc, w, l, d], ...], "boxes" => [[ref, iw, il, id, [[idx,x,y,z,w,l,d],...]], ...]}
  # Items are deduped (by value) and indexed; each box's packed items are in placement order.

  alias ExBoxPacker.{Box, Item}
  alias ExBoxPacker.Result.{PackedBox, PackedBoxList, PackedItemList}

  @spec build(PackedBoxList.t()) :: map()
  def build(%PackedBoxList{} = pbl) do
    boxes = PackedBoxList.to_list(pbl)
    packed_items = Enum.flat_map(boxes, &placement_ordered/1)

    {entries, index_of} =
      packed_items
      |> Enum.map(& &1.item)
      |> Enum.reduce({[], %{}}, fn item, {entries, index_of} ->
        if Map.has_key?(index_of, item) do
          {entries, index_of}
        else
          idx = map_size(index_of)

          {[
             {idx,
              [Item.description(item), Item.width(item), Item.length(item), Item.depth(item)]}
             | entries
           ], Map.put(index_of, item, idx)}
        end
      end)

    %{
      "items" => entries |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1)),
      "boxes" => Enum.map(boxes, fn pb -> box_entry(pb, index_of) end)
    }
  end

  @spec summary(PackedBoxList.t()) :: %{
          boxes: non_neg_integer(),
          items: non_neg_integer(),
          utilisation: float()
        }
  def summary(%PackedBoxList{} = pbl) do
    boxes = PackedBoxList.to_list(pbl)

    %{
      boxes: length(boxes),
      items: Enum.reduce(boxes, 0, fn pb, acc -> acc + PackedItemList.count(pb.items) end),
      utilisation: PackedBoxList.volume_utilisation(pbl)
    }
  end

  defp box_entry(%PackedBox{box: box} = pb, index_of) do
    placed =
      pb
      |> placement_ordered()
      |> Enum.map(fn pi ->
        [Map.fetch!(index_of, pi.item), pi.x, pi.y, pi.z, pi.width, pi.length, pi.depth]
      end)

    [
      Box.reference(box),
      Box.inner_width(box),
      Box.inner_length(box),
      Box.inner_depth(box),
      placed
    ]
  end

  # PackedItemList stores items newest-first (prepend on insert); reversing gives placement order.
  defp placement_ordered(%PackedBox{items: %PackedItemList{items: items}}),
    do: Enum.reverse(items)
end

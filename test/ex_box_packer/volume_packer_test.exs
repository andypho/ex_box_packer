defmodule ExBoxPacker.VolumePackerTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{PackedBox, PackedItemList, SimpleBox, SimpleItem, VolumePacker}

  defp box(iw, il, id, mw),
    do: %SimpleBox{
      reference: "b",
      outer_width: iw,
      outer_length: il,
      outer_depth: id,
      empty_weight: 0,
      inner_width: iw,
      inner_length: il,
      inner_depth: id,
      max_weight: mw
    }

  defp item(w, l, d, wt, rot),
    do: %SimpleItem{
      description: "i",
      width: w,
      length: l,
      depth: d,
      weight: wt,
      allowed_rotation: rot
    }

  defp fitted(packed_box), do: PackedItemList.count(packed_box.items)

  test "used dimensions calculated correctly" do
    items = List.duplicate(item(14, 12, 2, 2, :keep_flat), 5)
    packed = VolumePacker.pack(box(75, 15, 15, 30), items)
    assert PackedBox.used_width(packed) == 70
    assert PackedBox.used_length(packed) == 12
    assert PackedBox.used_depth(packed) == 2
  end

  test "issue 47A: 23 items fit" do
    items = List.duplicate(item(20, 69, 20, 0, :keep_flat), 23)
    assert fitted(VolumePacker.pack(box(165, 225, 25, 100), items)) == 23
  end

  test "issue 47B: 23 items fit" do
    items = List.duplicate(item(69, 20, 20, 0, :keep_flat), 23)
    assert fitted(VolumePacker.pack(box(165, 225, 25, 100), items)) == 23
  end

  test "allows rotated boxes in a new row: 9 items fit" do
    items = List.duplicate(item(30, 10, 30, 0, :keep_flat), 9)
    assert fitted(VolumePacker.pack(box(40, 70, 30, 1000), items)) == 9
  end

  test "unpacked space inside layers is filled (two box orientations): 3 items" do
    items = [
      item(8, 8, 2, 1, :best_fit),
      item(4, 4, 4, 1, :best_fit),
      item(4, 4, 4, 1, :best_fit)
    ]

    assert fitted(VolumePacker.pack(box(4, 14, 11, 100), items)) == 3
    assert fitted(VolumePacker.pack(box(14, 11, 4, 100), items)) == 3
  end
end

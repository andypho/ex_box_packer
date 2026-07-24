defmodule ExBoxPacker.PackedBoxTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Result.{PackedBox, PackedItem, PackedItemList}
  alias ExBoxPacker.{SimpleBox, SimpleItem}

  defp box do
    %SimpleBox{
      reference: "b",
      outer_width: 12,
      outer_length: 12,
      outer_depth: 12,
      empty_weight: 100,
      inner_width: 10,
      inner_length: 10,
      inner_depth: 10,
      max_weight: 1000
    }
  end

  defp packed_box(packed_items) do
    PackedBox.new(box(), PackedItemList.from_list(packed_items))
  end

  defp item(desc, w, l, d, weight),
    do: %SimpleItem{description: desc, width: w, length: l, depth: d, weight: weight}

  test "weight is empty box weight plus item weight" do
    pb = packed_box([PackedItem.new(item("a", 5, 5, 5, 40), 0, 0, 0, 5, 5, 5)])
    assert PackedBox.item_weight(pb) == 40
    assert PackedBox.weight(pb) == 140
    assert PackedBox.remaining_weight(pb) == 860
  end

  test "used and remaining dimensions" do
    pb = packed_box([PackedItem.new(item("a", 4, 6, 8, 1), 0, 0, 0, 4, 6, 8)])
    assert PackedBox.used_width(pb) == 4
    assert PackedBox.used_length(pb) == 6
    assert PackedBox.used_depth(pb) == 8
    assert PackedBox.remaining_width(pb) == 6
    assert PackedBox.remaining_length(pb) == 4
    assert PackedBox.remaining_depth(pb) == 2
  end

  test "volume accessors and utilisation" do
    pb = packed_box([PackedItem.new(item("a", 5, 5, 5, 1), 0, 0, 0, 5, 5, 5)])
    assert PackedBox.inner_volume(pb) == 1000
    assert PackedBox.used_volume(pb) == 125
    assert PackedBox.unused_volume(pb) == 875
    assert PackedBox.volume_utilisation(pb) == 12.5
  end

  test "validate/1 passes for an in-bounds, non-overlapping packing" do
    pb =
      packed_box([
        PackedItem.new(item("a", 5, 5, 5, 1), 0, 0, 0, 5, 5, 5),
        PackedItem.new(item("b", 5, 5, 5, 1), 5, 0, 0, 5, 5, 5)
      ])

    assert PackedBox.validate(pb) == :ok
  end

  test "validate/1 detects an out-of-bounds item" do
    pb = packed_box([PackedItem.new(item("a", 5, 5, 5, 1), 8, 0, 0, 5, 5, 5)])
    assert {:error, {:out_of_bounds, _}} = PackedBox.validate(pb)
  end

  test "validate/1 detects overlapping items" do
    pb =
      packed_box([
        PackedItem.new(item("a", 5, 5, 5, 1), 0, 0, 0, 5, 5, 5),
        PackedItem.new(item("b", 5, 5, 5, 1), 3, 0, 0, 5, 5, 5)
      ])

    assert {:error, {:overlap, _, _}} = PackedBox.validate(pb)
  end
end

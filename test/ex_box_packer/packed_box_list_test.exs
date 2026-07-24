defmodule ExBoxPacker.PackedBoxListTest do
  use ExUnit.Case, async: true

  alias ExBoxPacker.{
    PackedBox,
    PackedBoxList,
    PackedItem,
    PackedItemList,
    SimpleBox,
    SimpleItem
  }

  defp box(iw, il, id, empty) do
    %SimpleBox{
      reference: "b",
      outer_width: iw + 2,
      outer_length: il + 2,
      outer_depth: id + 2,
      empty_weight: empty,
      inner_width: iw,
      inner_length: il,
      inner_depth: id,
      max_weight: 10_000
    }
  end

  defp pi(w, l, d, weight) do
    PackedItem.new(
      %SimpleItem{description: "i", width: w, length: l, depth: d, weight: weight},
      0,
      0,
      0,
      w,
      l,
      d
    )
  end

  defp packed(box, items), do: PackedBox.new(box, PackedItemList.from_list(items))

  test "count and to_list reflect inserted boxes" do
    list =
      PackedBoxList.new()
      |> PackedBoxList.insert(packed(box(10, 10, 10, 1), [pi(2, 2, 2, 5)]))

    assert PackedBoxList.count(list) == 1
    assert [%PackedBox{}] = PackedBoxList.to_list(list)
  end

  test "to_list is ordered by the packed box sorter (more items first)" do
    one = packed(box(10, 10, 10, 1), [pi(2, 2, 2, 5)])
    two = packed(box(10, 10, 10, 1), [pi(2, 2, 2, 5), pi(2, 2, 2, 5)])

    list = PackedBoxList.from_list([one, two])
    assert [first, _second] = PackedBoxList.to_list(list)
    assert PackedItemList.count(first.items) == 2
  end

  test "mean_weight includes empty box weight" do
    a = packed(box(10, 10, 10, 100), [pi(2, 2, 2, 10)])
    b = packed(box(10, 10, 10, 100), [pi(2, 2, 2, 30)])
    list = PackedBoxList.from_list([a, b])
    # (110 + 130) / 2
    assert PackedBoxList.mean_weight(list) == 120.0
  end

  test "mean_item_weight excludes empty box weight" do
    a = packed(box(10, 10, 10, 100), [pi(2, 2, 2, 10)])
    b = packed(box(10, 10, 10, 100), [pi(2, 2, 2, 30)])
    list = PackedBoxList.from_list([a, b])
    assert PackedBoxList.mean_item_weight(list) == 20.0
  end

  test "weight_variance is rounded to one decimal place" do
    a = packed(box(10, 10, 10, 0), [pi(2, 2, 2, 10)])
    b = packed(box(10, 10, 10, 0), [pi(2, 2, 2, 30)])
    list = PackedBoxList.from_list([a, b])
    # mean 20; variance = ((10-20)^2 + (30-20)^2)/2 = 100.0
    assert PackedBoxList.weight_variance(list) == 100.0
  end

  test "volume_utilisation across all boxes, rounded to one dp" do
    a = packed(box(10, 10, 10, 0), [pi(5, 5, 5, 1)])
    list = PackedBoxList.from_list([a])
    # 125 / 1000 * 100
    assert PackedBoxList.volume_utilisation(list) == 12.5
  end
end

defmodule ExBoxPacker.PackedItemListTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Result.{PackedItem, PackedItemList}
  alias ExBoxPacker.SimpleItem

  defp packed(desc, w, l, d, weight),
    do:
      PackedItem.new(
        %SimpleItem{description: desc, width: w, length: l, depth: d, weight: weight},
        0,
        0,
        0,
        w,
        l,
        d
      )

  test "new/0 is empty" do
    list = PackedItemList.new()
    assert PackedItemList.count(list) == 0
    assert PackedItemList.weight(list) == 0
    assert PackedItemList.volume(list) == 0
  end

  test "insert accumulates count, weight and volume" do
    list =
      PackedItemList.new()
      |> PackedItemList.insert(packed("a", 2, 3, 4, 10))
      |> PackedItemList.insert(packed("b", 1, 1, 1, 5))

    assert PackedItemList.count(list) == 2
    assert PackedItemList.weight(list) == 15
    assert PackedItemList.volume(list) == 25
  end

  test "from_list builds from packed items" do
    list = PackedItemList.from_list([packed("a", 2, 3, 4, 10)])
    assert PackedItemList.count(list) == 1
    assert PackedItemList.volume(list) == 24
  end

  test "as_items returns the underlying Item values" do
    list = PackedItemList.from_list([packed("a", 2, 3, 4, 10)])
    assert [%SimpleItem{description: "a"}] = PackedItemList.as_items(list)
  end

  test "sorted orders by item volume desc then weight desc" do
    big = packed("big", 3, 3, 3, 1)
    small_heavy = packed("small_heavy", 1, 1, 1, 100)
    list = PackedItemList.from_list([small_heavy, big])

    assert PackedItemList.sorted(list) |> Enum.map(& &1.item.description) == [
             "big",
             "small_heavy"
           ]
  end

  test "sorted preserves insertion order for fully-tied items" do
    first = packed("first", 3, 3, 3, 5)
    second = packed("second", 3, 3, 3, 5)
    list = PackedItemList.from_list([first, second])
    assert PackedItemList.sorted(list) |> Enum.map(& &1.item.description) == ["first", "second"]
  end
end

defmodule ExBoxPacker.PackedItemTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{PackedItem, SimpleItem}

  test "new/7 stores placement and computes volume" do
    item = %SimpleItem{description: "x", width: 2, length: 3, depth: 4, weight: 1}
    packed = PackedItem.new(item, 5, 6, 7, 2, 3, 4)

    assert packed.item == item
    assert packed.x == 5
    assert packed.y == 6
    assert packed.z == 7
    assert packed.width == 2
    assert packed.length == 3
    assert packed.depth == 4
    assert packed.volume == 24
  end
end

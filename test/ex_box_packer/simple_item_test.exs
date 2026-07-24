defmodule ExBoxPacker.SimpleItemTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{Item, SimpleItem}

  setup do
    item = %SimpleItem{
      description: "widget",
      width: 10,
      length: 20,
      depth: 30,
      weight: 40,
      allowed_rotation: :best_fit
    }

    %{item: item}
  end

  test "quantity defaults to 1" do
    assert %SimpleItem{}.quantity == 1
  end

  test "allowed_rotation defaults to :best_fit" do
    assert %SimpleItem{}.allowed_rotation == :best_fit
  end

  test "implements the Item protocol", %{item: item} do
    assert Item.description(item) == "widget"
    assert Item.width(item) == 10
    assert Item.length(item) == 20
    assert Item.depth(item) == 30
    assert Item.weight(item) == 40
    assert Item.allowed_rotation(item) == :best_fit
  end
end

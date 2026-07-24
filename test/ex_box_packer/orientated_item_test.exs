defmodule ExBoxPacker.OrientatedItemTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{OrientatedItem, SimpleItem}

  defp item(w, l, d), do: %SimpleItem{description: "t", width: w, length: l, depth: d, weight: 1}

  test "new/4 sets dims and surface_footprint (width * length)" do
    o = OrientatedItem.new(item(2, 3, 4), 2, 3, 4)
    assert {o.width, o.length, o.depth} == {2, 3, 4}
    assert o.surface_footprint == 6
  end

  test "to_string is w|l|d" do
    assert to_string(OrientatedItem.new(item(1, 2, 3), 1, 2, 3)) == "1|2|3"
  end

  test "stable? is true for flat/low items and false for tall ones" do
    assert OrientatedItem.stable?(OrientatedItem.new(item(5, 5, 5), 5, 5, 5))
    assert OrientatedItem.stable?(OrientatedItem.new(item(3, 3, 10), 3, 3, 10))
    refute OrientatedItem.stable?(OrientatedItem.new(item(2, 2, 10), 2, 2, 10))
    refute OrientatedItem.stable?(OrientatedItem.new(item(1, 1, 10), 1, 1, 10))
  end

  test "stable? treats zero depth as depth 1 (no crash)" do
    assert OrientatedItem.stable?(OrientatedItem.new(item(5, 5, 0), 5, 5, 0))
  end

  test "same_dimensions? compares the sorted dimension multiset" do
    o = OrientatedItem.new(item(1, 2, 3), 2, 1, 3)
    assert OrientatedItem.same_dimensions?(o, item(3, 2, 1))
    refute OrientatedItem.same_dimensions?(o, item(1, 2, 2))
  end
end

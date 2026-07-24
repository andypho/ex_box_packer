defmodule ExBoxPacker.OrientatedItemSorterTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{OrientatedItem, OrientatedItemSorter, SimpleItem}

  defp oi(w, l, d),
    do: OrientatedItem.new(%SimpleItem{description: "i", width: w, length: l, depth: d, weight: 1}, w, l, d)

  test "prefers an exact width fit" do
    ctx = %{width_left: 10, length_left: 100, depth_left: 100}
    exact = oi(10, 5, 5)
    loose = oi(8, 5, 5)
    assert OrientatedItemSorter.compare(exact, loose, ctx) == -1
    assert OrientatedItemSorter.compare(loose, exact, ctx) == 1
  end

  test "when width ties, prefers an exact length fit" do
    ctx = %{width_left: 10, length_left: 10, depth_left: 100}
    a = oi(8, 10, 5)
    b = oi(8, 7, 5)
    assert OrientatedItemSorter.compare(a, b, ctx) == -1
  end

  test "otherwise prefers the smaller minimum gap" do
    ctx = %{width_left: 10, length_left: 10, depth_left: 100}
    tight = oi(8, 8, 5)
    loose = oi(6, 6, 5)
    assert OrientatedItemSorter.compare(tight, loose, ctx) == -1
  end

  test "on equal min gap, prefers the smaller surface footprint" do
    ctx = %{width_left: 10, length_left: 10, depth_left: 100}
    small = oi(2, 8, 5)
    big = oi(4, 8, 5)
    assert OrientatedItemSorter.compare(small, big, ctx) == -1
  end

  test "sort/2 orders best-first" do
    ctx = %{width_left: 10, length_left: 10, depth_left: 100}
    exact = oi(10, 5, 5)
    loose = oi(6, 6, 5)
    assert [%{width: 10} | _] = OrientatedItemSorter.sort([loose, exact], ctx)
  end
end

defmodule ExBoxPacker.DefaultItemSorterTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{DefaultItemSorter, SimpleItem}

  defp item(desc, w, l, d, weight),
    do: %SimpleItem{description: desc, width: w, length: l, depth: d, weight: weight}

  test "larger volume sorts first (negative result)" do
    big = item("big", 10, 10, 10, 1)
    small = item("small", 5, 5, 5, 1)
    assert DefaultItemSorter.compare(big, small) == -1
    assert DefaultItemSorter.compare(small, big) == 1
  end

  test "equal volume falls back to heavier first" do
    a = item("a", 10, 10, 10, 5)
    b = item("b", 10, 10, 10, 9)
    assert DefaultItemSorter.compare(a, b) == 1
    assert DefaultItemSorter.compare(b, a) == -1
  end

  test "equal volume and weight falls back to description asc" do
    a = item("aaa", 10, 10, 10, 5)
    b = item("bbb", 10, 10, 10, 5)
    assert DefaultItemSorter.compare(a, b) == -1
    assert DefaultItemSorter.compare(b, a) == 1
  end

  test "fully equal returns 0" do
    a = item("same", 10, 10, 10, 5)
    b = item("same", 10, 10, 10, 5)
    assert DefaultItemSorter.compare(a, b) == 0
  end
end

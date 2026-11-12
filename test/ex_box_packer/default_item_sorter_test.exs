defmodule ExBoxPacker.DefaultItemSorterTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.SimpleItem
  alias ExBoxPacker.Sorting.DefaultItemSorter
  alias ExBoxPacker.Test.LinkedTestItem

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

  # PHP's `<=>` compares two numeric strings as numbers, so "9" sorts before "10".
  test "numeric descriptions compare numerically" do
    a = item("9", 10, 10, 10, 5)
    b = item("10", 10, 10, 10, 5)
    assert DefaultItemSorter.compare(a, b) == -1
    assert DefaultItemSorter.compare(b, a) == 1
  end

  describe "linked items" do
    defp linked(desc, w, l, d, weight, group),
      do: %LinkedTestItem{
        description: desc,
        width: w,
        length: l,
        depth: d,
        weight: weight,
        linked_item_group: group
      }

    test "non-linked items sort before linked items regardless of volume" do
      small_plain = item("plain", 1, 1, 1, 1)
      big_linked = linked("linked", 10, 10, 10, 1, "g")
      assert DefaultItemSorter.compare(small_plain, big_linked) == -1
      assert DefaultItemSorter.compare(big_linked, small_plain) == 1
    end

    test "different groups sort by group identifier before volume" do
      small_a = linked("a", 1, 1, 1, 1, "group-a")
      big_b = linked("b", 10, 10, 10, 1, "group-b")
      assert DefaultItemSorter.compare(small_a, big_b) == -1
      assert DefaultItemSorter.compare(big_b, small_a) == 1
    end

    test "numeric group identifiers compare numerically" do
      big_9 = linked("a", 10, 10, 10, 1, "9")
      small_10 = linked("b", 1, 1, 1, 1, "10")
      assert DefaultItemSorter.compare(big_9, small_10) == -1
      assert DefaultItemSorter.compare(small_10, big_9) == 1
    end

    # "1e3" and "1000" are different identifiers but equal numbers, so PHP's `<=>` returns 0
    # rather than falling through to the size comparison.
    test "numerically equal group identifiers compare as equal" do
      big = linked("a", 10, 10, 10, 1, "1e3")
      small = linked("b", 1, 1, 1, 1, "1000")
      assert DefaultItemSorter.compare(big, small) == 0
    end

    test "items in the same group fall back to volume" do
      small = linked("small", 1, 1, 1, 1, "g")
      big = linked("big", 10, 10, 10, 1, "g")
      assert DefaultItemSorter.compare(big, small) == -1
    end
  end
end

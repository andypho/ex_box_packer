defmodule ExBoxPacker.DefaultPackedBoxSorterTest do
  use ExUnit.Case, async: true

  alias ExBoxPacker.{
    DefaultPackedBoxSorter,
    PackedBox,
    PackedItem,
    PackedItemList,
    SimpleBox,
    SimpleItem
  }

  defp box(iw, il, id) do
    %SimpleBox{
      reference: "b",
      outer_width: iw + 2,
      outer_length: il + 2,
      outer_depth: id + 2,
      empty_weight: 1,
      inner_width: iw,
      inner_length: il,
      inner_depth: id,
      max_weight: 10_000
    }
  end

  defp pi(w, l, d) do
    PackedItem.new(
      %SimpleItem{description: "i", width: w, length: l, depth: d, weight: 1},
      0,
      0,
      0,
      w,
      l,
      d
    )
  end

  defp packed(box, items), do: PackedBox.new(box, PackedItemList.from_list(items))

  test "more items sorts first (negative result)" do
    two = packed(box(10, 10, 10), [pi(2, 2, 2), pi(2, 2, 2)])
    one = packed(box(10, 10, 10), [pi(2, 2, 2)])
    assert DefaultPackedBoxSorter.compare(two, one) == -1
    assert DefaultPackedBoxSorter.compare(one, two) == 1
  end

  test "equal item count falls back to higher utilisation first" do
    tight = packed(box(4, 4, 4), [pi(4, 4, 4)])
    loose = packed(box(10, 10, 10), [pi(4, 4, 4)])
    assert DefaultPackedBoxSorter.compare(tight, loose) == -1
    assert DefaultPackedBoxSorter.compare(loose, tight) == 1
  end
end

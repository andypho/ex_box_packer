defmodule ExBoxPacker.DefaultBoxSorterTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{DefaultBoxSorter, SimpleBox}

  defp box(ref, iw, il, id, empty, max) do
    %SimpleBox{
      reference: ref,
      outer_width: iw + 2,
      outer_length: il + 2,
      outer_depth: id + 2,
      empty_weight: empty,
      inner_width: iw,
      inner_length: il,
      inner_depth: id,
      max_weight: max
    }
  end

  test "smallest inner volume sorts first" do
    small = box("small", 10, 10, 10, 1, 100)
    big = box("big", 20, 20, 20, 1, 100)
    assert DefaultBoxSorter.compare(small, big) == -1
    assert DefaultBoxSorter.compare(big, small) == 1
  end

  test "equal volume falls back to smaller empty weight" do
    a = box("a", 10, 10, 10, 5, 100)
    b = box("b", 10, 10, 10, 2, 100)
    assert DefaultBoxSorter.compare(a, b) == 1
    assert DefaultBoxSorter.compare(b, a) == -1
  end

  test "equal volume and empty weight falls back to usable capacity asc" do
    a = box("a", 10, 10, 10, 5, 50)
    b = box("b", 10, 10, 10, 5, 80)
    assert DefaultBoxSorter.compare(a, b) == -1
    assert DefaultBoxSorter.compare(b, a) == 1
  end
end

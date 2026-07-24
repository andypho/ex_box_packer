defmodule ExBoxPacker.BoxListTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{BoxList, SimpleBox}

  defp box(ref, iw, il, id) do
    %SimpleBox{
      reference: ref,
      outer_width: iw + 2,
      outer_length: il + 2,
      outer_depth: id + 2,
      empty_weight: 1,
      inner_width: iw,
      inner_length: il,
      inner_depth: id,
      max_weight: 100
    }
  end

  test "sort orders boxes smallest inner volume first" do
    big = box("big", 20, 20, 20)
    small = box("small", 10, 10, 10)
    mid = box("mid", 15, 15, 15)
    assert BoxList.sort([big, small, mid]) |> Enum.map(& &1.reference) == ["small", "mid", "big"]
  end
end

defmodule ExBoxPacker.Preview.PayloadTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Packer
  alias ExBoxPacker.Preview.Payload
  alias ExBoxPacker.{SimpleBox, SimpleItem}

  defp box(ref, s),
    do: %SimpleBox{
      reference: ref,
      outer_width: s,
      outer_length: s,
      outer_depth: s,
      empty_weight: 0,
      inner_width: s,
      inner_length: s,
      inner_depth: s,
      max_weight: 1_000_000
    }

  defp item(desc, d),
    do: %SimpleItem{
      description: desc,
      width: d,
      length: d,
      depth: d,
      weight: 1,
      allowed_rotation: :best_fit
    }

  test "build/1 produces the items+boxes shape with placement-ordered items" do
    {:ok, pbl} = Packer.pack([box("B", 10)], [item("cube", 5), item("cube", 5)])
    payload = Payload.build(pbl)

    assert %{"items" => items, "boxes" => boxes} = payload
    # one deduped item type ("cube")
    assert [["cube", 5, 5, 5]] = items
    assert [["B", 10, 10, 10, placed]] = boxes
    # two placed cubes, each referencing item index 0, with 7-tuples [idx,x,y,z,w,l,d]
    assert length(placed) == 2

    assert Enum.all?(placed, fn [idx, _x, _y, _z, w, l, d] ->
             idx == 0 and [w, l, d] == [5, 5, 5]
           end)
  end

  test "summary/1 reports box count, item count and utilisation" do
    {:ok, pbl} = Packer.pack([box("B", 10)], [item("cube", 5), item("cube", 5)])
    assert %{boxes: 1, items: 2, utilisation: util} = Payload.summary(pbl)
    assert is_float(util)
  end
end

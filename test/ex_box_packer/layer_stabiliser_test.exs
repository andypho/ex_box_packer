defmodule ExBoxPacker.LayerStabiliserTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{LayerStabiliser, PackedItem, PackedLayer, SimpleItem}

  defp pi(x, y, z, w, l, d) do
    PackedItem.new(%SimpleItem{description: "i", width: w, length: l, depth: d, weight: 1}, x, y, z, w, l, d)
  end

  test "reorders layers largest-footprint first and restacks z from 0" do
    # small-footprint layer sitting on top (z=0), big-footprint layer above it (z=5)
    small = PackedLayer.new() |> PackedLayer.insert(pi(0, 0, 0, 2, 2, 5))
    big = PackedLayer.new() |> PackedLayer.insert(pi(0, 0, 5, 10, 10, 3))

    [first, second] = LayerStabiliser.stabilise([small, big])

    # big footprint (100) now first, restacked to z=0
    assert PackedLayer.footprint(first) == 100
    assert [%{z: 0, depth: 3}] = PackedLayer.items(first)
    # small footprint now on top, its z shifted to start after the big layer (depth 3)
    assert PackedLayer.footprint(second) == 4
    assert [%{z: 3, depth: 5}] = PackedLayer.items(second)
  end
end

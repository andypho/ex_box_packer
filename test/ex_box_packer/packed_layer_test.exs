defmodule ExBoxPacker.PackedLayerTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Result.{PackedItem, PackedLayer}
  alias ExBoxPacker.SimpleItem

  defp at(x, y, z, w, l, d, weight) do
    PackedItem.new(
      %SimpleItem{description: "i", width: w, length: l, depth: d, weight: weight},
      x,
      y,
      z,
      w,
      l,
      d
    )
  end

  test "empty layer reports zero dimensions and weight" do
    layer = PackedLayer.new()
    assert PackedLayer.width(layer) == 0
    assert PackedLayer.length(layer) == 0
    assert PackedLayer.depth(layer) == 0
    assert PackedLayer.footprint(layer) == 0
    assert PackedLayer.weight(layer) == 0
  end

  test "geometry spans the min/max extents of inserted items" do
    layer =
      PackedLayer.new()
      |> PackedLayer.insert(at(0, 0, 0, 10, 20, 5, 3))
      |> PackedLayer.insert(at(10, 0, 0, 10, 20, 8, 4))

    assert PackedLayer.start_x(layer) == 0
    assert PackedLayer.end_x(layer) == 20
    assert PackedLayer.width(layer) == 20
    assert PackedLayer.start_y(layer) == 0
    assert PackedLayer.end_y(layer) == 20
    assert PackedLayer.length(layer) == 20
    assert PackedLayer.start_z(layer) == 0
    assert PackedLayer.end_z(layer) == 8
    assert PackedLayer.depth(layer) == 8
    assert PackedLayer.footprint(layer) == 400
    assert PackedLayer.weight(layer) == 7
  end

  test "merge combines items from another layer" do
    a = PackedLayer.new() |> PackedLayer.insert(at(0, 0, 0, 10, 10, 10, 1))
    b = PackedLayer.new() |> PackedLayer.insert(at(10, 0, 0, 10, 10, 10, 1))
    merged = PackedLayer.merge(a, b)
    assert length(PackedLayer.items(merged)) == 2
    assert PackedLayer.width(merged) == 20
  end
end

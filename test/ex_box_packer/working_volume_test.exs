defmodule ExBoxPacker.WorkingVolumeTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Box
  alias ExBoxPacker.Engine.WorkingVolume

  test "implements Box with equal inner/outer dims and zero empty weight" do
    v = %WorkingVolume{width: 10, length: 20, depth: 30, max_weight: 500}
    assert Box.reference(v) == "Working Volume 10x20x30"
    assert Box.outer_width(v) == 10 and Box.inner_width(v) == 10
    assert Box.outer_length(v) == 20 and Box.inner_length(v) == 20
    assert Box.outer_depth(v) == 30 and Box.inner_depth(v) == 30
    assert Box.empty_weight(v) == 0
    assert Box.max_weight(v) == 500
  end
end

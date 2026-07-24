defmodule ExBoxPacker.SimpleBoxTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{Box, SimpleBox}

  setup do
    box = %SimpleBox{
      reference: "carton",
      outer_width: 102,
      outer_length: 202,
      outer_depth: 302,
      empty_weight: 5,
      inner_width: 100,
      inner_length: 200,
      inner_depth: 300,
      max_weight: 1000
    }

    %{box: box}
  end

  test "implements the Box protocol", %{box: box} do
    assert Box.reference(box) == "carton"
    assert Box.outer_width(box) == 102
    assert Box.outer_length(box) == 202
    assert Box.outer_depth(box) == 302
    assert Box.empty_weight(box) == 5
    assert Box.inner_width(box) == 100
    assert Box.inner_length(box) == 200
    assert Box.inner_depth(box) == 300
    assert Box.max_weight(box) == 1000
  end
end

defmodule ExBoxPacker.RoundingTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Engine.Rounding

  test "rounds half away from zero to 1 dp (matches PHP round/2)" do
    assert Rounding.round_half_up(0.15, 1) == 0.2
    assert Rounding.round_half_up(0.35, 1) == 0.4
    assert Rounding.round_half_up(2.55, 1) == 2.6
    assert Rounding.round_half_up(83.35, 1) == 83.4
    assert Rounding.round_half_up(12.5, 1) == 12.5
  end

  test "handles values that need no rounding" do
    assert Rounding.round_half_up(27.1, 1) == 27.1
    assert Rounding.round_half_up(100.0, 1) == 100.0
    assert Rounding.round_half_up(0.0, 1) == 0.0
  end

  test "rounds negatives away from zero" do
    assert Rounding.round_half_up(-0.15, 1) == -0.2
    assert Rounding.round_half_up(-2.55, 1) == -2.6
  end

  test "supports precision 0" do
    assert Rounding.round_half_up(2.5, 0) == 3.0
    assert Rounding.round_half_up(-2.5, 0) == -3.0
  end
end

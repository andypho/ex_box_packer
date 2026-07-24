defmodule ExBoxPacker.RotationTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Rotation

  test "values/0 lists the allowed rotations" do
    assert Rotation.values() == [:never, :keep_flat, :best_fit]
  end

  test "valid?/1 accepts allowed rotations and rejects others" do
    assert Rotation.valid?(:never)
    assert Rotation.valid?(:keep_flat)
    assert Rotation.valid?(:best_fit)
    refute Rotation.valid?(:sideways)
  end

  test "permutation_count/1 mirrors BoxPacker's enum values" do
    assert Rotation.permutation_count(:never) == 1
    assert Rotation.permutation_count(:keep_flat) == 2
    assert Rotation.permutation_count(:best_fit) == 6
  end
end

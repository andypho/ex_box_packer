defmodule ExBoxPacker.ItemSpecTest do
  use ExUnit.Case, async: true

  alias ExBoxPacker.Engine.ItemSpec
  alias ExBoxPacker.SimpleItem

  defp item(w, l, d, opts \\ []) do
    %SimpleItem{
      description: Keyword.get(opts, :description, "i"),
      width: w,
      length: l,
      depth: d,
      weight: Keyword.get(opts, :weight, 10),
      allowed_rotation: Keyword.get(opts, :rotation, :best_fit),
      quantity: 1
    }
  end

  test "wrap/1 copies the protocol values onto flat fields" do
    spec = ItemSpec.wrap(item(3, 5, 7, weight: 11, rotation: :keep_flat))

    assert spec.width == 3
    assert spec.length == 5
    assert spec.depth == 7
    assert spec.weight == 11
    assert spec.rotation == :keep_flat
  end

  test "wrap/1 retains the original item" do
    original = item(3, 5, 7)
    assert ItemSpec.wrap(original).item == original
  end

  test "wrap/1 precomputes volume" do
    assert ItemSpec.wrap(item(3, 5, 7)).volume == 105
  end

  test "wrap/1 precomputes ascending sorted_dims" do
    assert ItemSpec.wrap(item(7, 3, 5)).sorted_dims == [3, 5, 7]
  end

  test "wrap/1 is idempotent on an already-wrapped spec" do
    spec = ItemSpec.wrap(item(3, 5, 7))
    assert ItemSpec.wrap(spec) == spec
  end

  test "spec?/1 distinguishes specs from raw items" do
    assert ItemSpec.spec?(ItemSpec.wrap(item(1, 1, 1)))
    refute ItemSpec.spec?(item(1, 1, 1))
  end

  test "user_item/1 unwraps a spec and passes a raw item through" do
    original = item(3, 5, 7)
    assert ItemSpec.user_item(ItemSpec.wrap(original)) == original
    assert ItemSpec.user_item(original) == original
  end

  test "does NOT implement the Item protocol" do
    spec = ItemSpec.wrap(item(3, 5, 7))
    assert ExBoxPacker.Item.impl_for(spec) == nil
  end
end

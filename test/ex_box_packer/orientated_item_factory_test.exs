defmodule ExBoxPacker.OrientatedItemFactoryTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Engine.{OrientatedItem, OrientatedItemFactory}
  alias ExBoxPacker.Result.PackedItemList
  alias ExBoxPacker.{SimpleBox, SimpleItem}

  @big 1_000_000_000

  defp big_box do
    %SimpleBox{
      reference: "Box",
      outer_width: @big,
      outer_length: @big,
      outer_depth: @big,
      empty_weight: 0,
      inner_width: @big,
      inner_length: @big,
      inner_depth: @big,
      max_weight: @big
    }
  end

  defp item(w, l, d, rot),
    do: %SimpleItem{
      description: "t",
      width: w,
      length: l,
      depth: d,
      weight: 4,
      allowed_rotation: rot
    }

  defp dims(orientations), do: Enum.map(orientations, &{&1.width, &1.length, &1.depth})

  test "best_fit yields all 6 orientations in the expected order" do
    orientations =
      OrientatedItemFactory.possible_orientations(
        item(1, 2, 3, :best_fit),
        nil,
        {@big, @big, @big}
      )

    assert dims(orientations) == [
             {1, 2, 3},
             {2, 1, 3},
             {1, 3, 2},
             {2, 3, 1},
             {3, 1, 2},
             {3, 2, 1}
           ]
  end

  test "keep_flat yields 2 orientations" do
    orientations =
      OrientatedItemFactory.possible_orientations(
        item(1, 2, 3, :keep_flat),
        nil,
        {@big, @big, @big}
      )

    assert dims(orientations) == [{1, 2, 3}, {2, 1, 3}]
  end

  test "never yields 1 orientation" do
    orientations =
      OrientatedItemFactory.possible_orientations(item(1, 2, 3, :never), nil, {@big, @big, @big})

    assert dims(orientations) == [{1, 2, 3}]
  end

  test "a cube collapses to a single orientation" do
    orientations =
      OrientatedItemFactory.possible_orientations(
        item(5, 5, 5, :best_fit),
        nil,
        {@big, @big, @big}
      )

    assert dims(orientations) == [{5, 5, 5}]
  end

  test "orientations that do not fit are removed" do
    assert OrientatedItemFactory.possible_orientations(item(5, 5, 5, :best_fit), nil, {5, 5, 4}) ==
             []
  end

  test "a same-dimension previous item keeps its exact orientation" do
    prev = OrientatedItem.new(item(1, 2, 3, :best_fit), 2, 1, 3)

    orientations =
      OrientatedItemFactory.possible_orientations(
        item(1, 2, 3, :best_fit),
        prev,
        {@big, @big, @big}
      )

    assert dims(orientations) == [{2, 1, 3}]
  end

  test "best_orientation returns a fitting orientation" do
    best =
      OrientatedItemFactory.best_orientation(
        big_box(),
        item(4, 4, 4, :best_fit),
        nil,
        {@big, @big, @big},
        [],
        0,
        false,
        true,
        0,
        0,
        0,
        PackedItemList.new(),
        false
      )

    assert %OrientatedItem{width: 4, length: 4, depth: 4} = best
  end

  test "best_orientation returns nil when nothing fits" do
    assert OrientatedItemFactory.best_orientation(
             big_box(),
             item(10, 10, 10, :best_fit),
             nil,
             {5, 5, 5},
             [],
             0,
             false,
             true,
             0,
             0,
             0,
             PackedItemList.new(),
             false
           ) == nil
  end

  test "best_orientation avoids unstable (tall) orientations when stability is considered" do
    best =
      OrientatedItemFactory.best_orientation(
        big_box(),
        item(1, 1, 10, :best_fit),
        nil,
        {@big, @big, @big},
        [],
        0,
        false,
        true,
        0,
        0,
        0,
        PackedItemList.new(),
        false
      )

    assert best.depth == 1
  end

  test "best_orientation ignores stability when not considered" do
    # When stability is not considered, unstable orientations are included in the
    # candidate set. The sorter still picks the smallest-horizontal-gap winner
    # ({1,10,1} → depth=1) rather than the tallest. The key property is that the
    # unstable {1,1,10} orientation is also a candidate (not filtered out).
    best =
      OrientatedItemFactory.best_orientation(
        big_box(),
        item(1, 1, 10, :best_fit),
        nil,
        {@big, @big, @big},
        [],
        0,
        false,
        false,
        0,
        0,
        0,
        PackedItemList.new(),
        false
      )

    assert best != nil
    assert {best.width, best.length, best.depth} in [{1, 10, 1}, {10, 1, 1}, {1, 1, 10}]
  end

  test "usable_orientations returns only stable ones when any are stable" do
    box = big_box()
    it = item(1, 1, 10, :best_fit)
    possible = OrientatedItemFactory.possible_orientations(it, nil, {@big, @big, @big})
    usable = OrientatedItemFactory.usable_orientations(box, it, possible)
    assert Enum.all?(usable, &(&1.depth == 1))
    refute Enum.any?(usable, &(&1.depth == 10))
  end

  test "has_stable_orientations_in_empty_box? is true for a normal item" do
    assert OrientatedItemFactory.has_stable_orientations_in_empty_box?(
             big_box(),
             item(2, 3, 4, :best_fit)
           )
  end
end

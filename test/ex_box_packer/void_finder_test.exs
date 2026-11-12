defmodule ExBoxPacker.VoidFinderTest do
  # Port of BoxPacker's tests/VoidFinderTest.php (added in 4.3.0).
  use ExUnit.Case, async: true

  alias ExBoxPacker.Engine.{VoidFinder, VoidSpace}
  alias ExBoxPacker.Result.PackedItem
  alias ExBoxPacker.SimpleItem

  defp packed(desc, x, y, z, w, l, d),
    do:
      PackedItem.new(
        %SimpleItem{description: desc, width: w, length: l, depth: d, weight: 1},
        x,
        y,
        z,
        w,
        l,
        d
      )

  defp void(x, y, z, w, l, d), do: VoidSpace.new(x, y, z, w, l, d)

  test "an empty box is a single full void" do
    assert [space] = VoidFinder.find(100, 80, 60, [])
    assert space == void(0, 0, 0, 100, 80, 60)
    assert space.volume == 100 * 80 * 60
    assert space.footprint == 100 * 80
  end

  test "a single item in the corner produces residuals on the open sides" do
    item = packed("i", 0, 0, 0, 40, 30, 20)
    spaces = VoidFinder.find(100, 80, 60, [item])

    assert spaces != []
    assert_voids_do_not_intersect(spaces, [item])
    assert_voids_inside_box(spaces, 100, 80, 60)
    assert void(40, 0, 0, 60, 80, 60) in spaces, "space to the right of the item"
    assert void(0, 30, 0, 40, 50, 60) in spaces, "space behind the item"
    assert void(0, 0, 20, 40, 30, 40) in spaces, "space above the item"
  end

  test "a single item in the centre produces internal and exterior voids" do
    item = packed("i", 30, 20, 10, 40, 30, 20)
    spaces = VoidFinder.find(100, 80, 60, [item])

    assert spaces != []
    assert_voids_do_not_intersect(spaces, [item])
    assert_voids_inside_box(spaces, 100, 80, 60)
    assert void(0, 0, 0, 30, 80, 60) in spaces, "left of item"
    assert void(70, 0, 0, 30, 80, 60) in spaces, "right of item"
    assert void(30, 0, 0, 40, 20, 60) in spaces, "front of item"
    assert void(30, 50, 0, 40, 30, 60) in spaces, "back of item"
    assert void(30, 20, 0, 40, 30, 10) in spaces, "below item"
    assert void(30, 20, 30, 40, 30, 30) in spaces, "above item"
  end

  test "two items leave an internal pocket" do
    left = packed("left", 0, 0, 0, 40, 50, 50)
    right = packed("right", 60, 0, 0, 40, 50, 50)
    spaces = VoidFinder.find(100, 50, 50, [left, right])

    assert_voids_do_not_intersect(spaces, [left, right])
    assert_voids_inside_box(spaces, 100, 50, 50)
    assert void(40, 0, 0, 20, 50, 50) in spaces
  end

  test "a fully packed box has no voids" do
    assert VoidFinder.find(100, 80, 60, [packed("i", 0, 0, 0, 100, 80, 60)]) == []
  end

  test "subtract_items/2 refines an existing partition" do
    left = packed("left", 0, 0, 0, 40, 50, 50)
    right = packed("right", 60, 0, 0, 40, 50, 50)

    after_both = 100 |> VoidFinder.find(50, 50, [left]) |> VoidFinder.subtract_items([right])

    assert_voids_do_not_intersect(after_both, [left, right])
    assert_voids_inside_box(after_both, 100, 50, 50)
    assert void(40, 0, 0, 20, 50, 50) in after_both
  end

  # Not in the PHP suite: fillVoids iterates voids in list order (after a stable sort), so
  # the order itself must match. Expected list captured from BoxPacker 4.3.0's VoidFinder.
  test "residuals are produced in BoxPacker's order" do
    centre = packed("a", 30, 20, 10, 40, 30, 20)
    corner = packed("b", 0, 0, 0, 10, 10, 10)

    assert VoidFinder.find(100, 80, 60, [centre, corner]) == [
             void(10, 0, 0, 20, 80, 60),
             void(0, 10, 0, 10, 70, 60),
             void(0, 0, 10, 10, 10, 50),
             void(70, 0, 0, 30, 80, 60),
             void(30, 0, 0, 40, 20, 60),
             void(30, 50, 0, 40, 30, 60),
             void(30, 20, 0, 40, 30, 10),
             void(30, 20, 30, 40, 30, 30)
           ]
  end

  defp assert_voids_do_not_intersect(spaces, items) do
    for s <- spaces, i <- items do
      overlap? =
        s.x < i.x + i.width and i.x < s.x + s.width and
          s.y < i.y + i.length and i.y < s.y + s.length and
          s.z < i.z + i.depth and i.z < s.z + s.depth

      refute overlap?, "void #{inspect(s)} intersects packed item #{inspect(i)}"
    end
  end

  defp assert_voids_inside_box(spaces, box_width, box_length, box_depth) do
    for s <- spaces do
      assert s.x >= 0 and s.y >= 0 and s.z >= 0
      assert s.x + s.width <= box_width
      assert s.y + s.length <= box_length
      assert s.z + s.depth <= box_depth
      assert s.width > 0 and s.length > 0 and s.depth > 0
    end
  end
end

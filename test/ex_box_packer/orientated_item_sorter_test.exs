defmodule ExBoxPacker.OrientatedItemSorterTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Engine.{ItemSpec, OrientatedItem, OrientatedItemSorter}
  alias ExBoxPacker.Result.PackedItemList
  alias ExBoxPacker.SimpleItem

  defp spec(w, l, d, rotation \\ :best_fit),
    do:
      ItemSpec.wrap(%SimpleItem{
        description: "i",
        width: w,
        length: l,
        depth: d,
        weight: 1,
        allowed_rotation: rotation
      })

  defp oi(w, l, d), do: OrientatedItem.new(spec(w, l, d), w, l, d)

  # Orientation `{w, l, d}` of an existing item spec.
  defp orient(%ItemSpec{} = s, {w, l, d}), do: OrientatedItem.new(s, w, l, d)

  defp ctx(width_left, length_left, depth_left, next_items) do
    %{
      box: nil,
      width_left: width_left,
      length_left: length_left,
      depth_left: depth_left,
      next_items: next_items,
      row_length: 0,
      single_pass?: true,
      x: 0,
      y: 0,
      z: 0,
      packed: PackedItemList.new(),
      box_rotated?: false
    }
  end

  test "prefers an exact width fit" do
    ctx = %{
      box: nil,
      width_left: 10,
      length_left: 100,
      depth_left: 100,
      next_items: [],
      row_length: 0,
      single_pass?: true
    }

    exact = oi(10, 5, 5)
    loose = oi(8, 5, 5)
    assert OrientatedItemSorter.compare(exact, loose, ctx) == -1
    assert OrientatedItemSorter.compare(loose, exact, ctx) == 1
  end

  test "when width ties, prefers an exact length fit" do
    ctx = %{
      box: nil,
      width_left: 10,
      length_left: 10,
      depth_left: 100,
      next_items: [],
      row_length: 0,
      single_pass?: true
    }

    a = oi(8, 10, 5)
    b = oi(8, 7, 5)
    assert OrientatedItemSorter.compare(a, b, ctx) == -1
  end

  test "otherwise prefers the smaller minimum gap" do
    ctx = %{
      box: nil,
      width_left: 10,
      length_left: 10,
      depth_left: 100,
      next_items: [],
      row_length: 0,
      single_pass?: true
    }

    tight = oi(8, 8, 5)
    loose = oi(6, 6, 5)
    assert OrientatedItemSorter.compare(tight, loose, ctx) == -1
  end

  test "on equal min gap, prefers the smaller surface footprint" do
    ctx = %{
      box: nil,
      width_left: 10,
      length_left: 10,
      depth_left: 100,
      next_items: [],
      row_length: 0,
      single_pass?: true
    }

    small = oi(2, 8, 5)
    big = oi(4, 8, 5)
    assert OrientatedItemSorter.compare(small, big, ctx) == -1
  end

  test "sort/2 orders best-first" do
    ctx = %{
      box: nil,
      width_left: 10,
      length_left: 10,
      depth_left: 100,
      next_items: [],
      row_length: 0,
      single_pass?: true
    }

    exact = oi(10, 5, 5)
    loose = oi(6, 6, 5)
    assert [%{width: 10} | _] = OrientatedItemSorter.sort([loose, exact], ctx)
  end

  describe "same-size items" do
    # 60x40x25 free space, 30x20x11 items: {30, 20, 11} tiles 2*2*2 = 8, {20, 30, 11} only
    # 3*1*2 = 6. Min-gap alone would pick {20, 30, 11} (gap 10 vs 20).
    test "prefers the orientation that tiles more of the remaining same-size items" do
      item = spec(30, 20, 11)
      more = orient(item, {30, 20, 11})
      fewer = orient(item, {20, 30, 11})
      c = ctx(60, 40, 25, List.duplicate(spec(30, 20, 11), 3))

      assert OrientatedItemSorter.compare(more, fewer, c) == -1
      assert OrientatedItemSorter.compare(fewer, more, c) == 1
    end

    test "does not apply when the remaining items differ in size" do
      item = spec(30, 20, 11)
      more = orient(item, {30, 20, 11})
      fewer = orient(item, {20, 30, 11})
      c = ctx(60, 40, 25, [spec(30, 20, 11), spec(5, 5, 5)])

      # falls through to min-gap, which prefers the 10mm gap
      assert OrientatedItemSorter.compare(fewer, more, c) == -1
    end

    test "does not apply to the last item" do
      item = spec(30, 20, 11)
      more = orient(item, {30, 20, 11})
      fewer = orient(item, {20, 30, 11})

      assert OrientatedItemSorter.compare(fewer, more, ctx(60, 40, 25, [])) == -1
    end
  end

  describe "slab-like items" do
    # 100x80x10: thinnest/longest edge = 0.1 <= 0.3. Both orientations tie on min-gap (100),
    # and the smaller-footprint fallback would stand the slab on its edge.
    test "prefer the thin edge as depth" do
      slab = spec(100, 80, 10)
      flat = orient(slab, {100, 80, 10})
      on_edge = orient(slab, {100, 10, 80})
      c = ctx(200, 200, 200, [])

      assert OrientatedItemSorter.compare(flat, on_edge, c) == -1
      assert OrientatedItemSorter.compare(on_edge, flat, c) == 1
    end

    test "items above the slab aspect ratio keep the footprint fallback" do
      block = spec(100, 80, 40)
      flat = orient(block, {100, 80, 40})
      on_edge = orient(block, {100, 40, 80})

      assert OrientatedItemSorter.compare(on_edge, flat, ctx(200, 200, 200, [])) == -1
    end
  end
end

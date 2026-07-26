defmodule ExBoxPacker.PackerTest do
  use ExUnit.Case, async: true

  alias ExBoxPacker.{NoBoxesAvailableError, Packer, SimpleBox, SimpleItem}
  alias ExBoxPacker.Result.{PackedBox, PackedBoxList, PackedItemList}

  # Reverse-reference sorter: prefers the box whose reference sorts LAST.
  defmodule ReverseRefSorter do
    @behaviour ExBoxPacker.Sorting.PackedBoxSorter
    @impl true
    def compare(a, b) do
      cond do
        a.box.reference > b.box.reference -> -1
        a.box.reference < b.box.reference -> 1
        true -> 0
      end
    end
  end

  defp box(ref, iw, il, id, empty, mw) do
    %SimpleBox{
      reference: ref,
      outer_width: iw,
      outer_length: il,
      outer_depth: id,
      empty_weight: empty,
      inner_width: iw,
      inner_length: il,
      inner_depth: id,
      max_weight: mw
    }
  end

  defp full_box(ref, {ow, ol, od}, empty, iw, il, id, mw) do
    %SimpleBox{
      reference: ref,
      outer_width: ow,
      outer_length: ol,
      outer_depth: od,
      empty_weight: empty,
      inner_width: iw,
      inner_length: il,
      inner_depth: id,
      max_weight: mw
    }
  end

  defp item(desc, w, l, d, wt, rot),
    do: %SimpleItem{
      description: desc,
      width: w,
      length: l,
      depth: d,
      weight: wt,
      allowed_rotation: rot
    }

  test "error when an item fits no box (throwing)" do
    boxes = [
      full_box("small", {300, 300, 10}, 10, 296, 296, 8, 1000),
      full_box("grande", {3000, 3000, 100}, 100, 2960, 2960, 80, 10_000)
    ]

    items = [
      item("1", 2500, 2500, 20, 2000, :best_fit),
      item("2", 25_000, 2500, 20, 2000, :best_fit),
      item("3", 2500, 2500, 20, 2000, :best_fit)
    ]

    assert {:error, %NoBoxesAvailableError{}} = Packer.pack(boxes, items)
  end

  test "error when there are no boxes" do
    assert {:error, %NoBoxesAvailableError{affected_items: [_ | _]}} =
             Packer.pack([], [item("1", 10, 10, 10, 1, :best_fit)])
  end

  test "pack!/3 raises on unpackable" do
    assert_raise NoBoxesAvailableError, fn ->
      Packer.pack!([], [item("x", 10, 10, 10, 1, :best_fit)])
    end
  end

  test "empty item list yields an empty result" do
    {:ok, pbl} = Packer.pack([box("Box", 10, 10, 10, 0, 100)], [])
    assert PackedBoxList.count(pbl) == 0
  end

  test "issue 52A: two identical items in one box, used dims 30x13x8" do
    items = List.duplicate(item("Item", 15, 13, 8, 407, :keep_flat), 2)
    {:ok, pbl} = Packer.pack([box("Box", 100, 50, 50, 0, 5000)], items)
    assert PackedBoxList.count(pbl) == 1
    top = PackedBoxList.top(pbl)
    assert PackedBox.used_width(top) == 30
    assert PackedBox.used_length(top) == 13
    assert PackedBox.used_depth(top) == 8
  end

  test "issue 117: picks the smaller box that still fits both items" do
    boxes = [box("Box A", 36, 8, 3, 0, 2), box("Box B", 36, 8, 8, 0, 2)]
    items = [item("1", 35, 7, 2, 1, :best_fit), item("2", 6, 5, 1, 1, :best_fit)]
    {:ok, pbl} = Packer.pack(boxes, items)
    assert PackedBoxList.count(pbl) == 1
    assert PackedBoxList.top(pbl).box.reference == "Box A"
  end

  test "issue 168: picks the Small box" do
    boxes = [box("Small", 85, 190, 230, 30, 10_000), box("Medium", 220, 160, 160, 50, 10_000)]
    {:ok, pbl} = Packer.pack(boxes, [item("Item", 55, 85, 122, 350, :best_fit)])
    assert PackedBoxList.count(pbl) == 1
    assert PackedBoxList.top(pbl).box.reference == "Small"
  end

  test "issue 38: spills into two boxes" do
    boxes = [box("Box1", 2, 2, 2, 0, 1000), box("Box2", 4, 4, 4, 0, 1000)]

    items =
      List.duplicate(item("s", 1, 1, 1, 100, :best_fit), 4) ++
        List.duplicate(item("m", 2, 2, 2, 100, :best_fit), 4) ++
        [item("l", 4, 4, 4, 100, :best_fit)]

    {:ok, pbl} = Packer.pack(boxes, items)
    assert PackedBoxList.count(pbl) == 2
  end

  test "pack_all_possible leaves the too-large item unpacked" do
    boxes = [
      full_box("small", {300, 300, 10}, 10, 296, 296, 8, 1000),
      full_box("grande", {3000, 3000, 100}, 100, 2960, 2960, 80, 10_000)
    ]

    items = [
      item("1", 2500, 2500, 20, 2000, :best_fit),
      item("2", 25_000, 2500, 20, 2000, :best_fit),
      item("3", 2500, 2500, 20, 2000, :best_fit)
    ]

    {pbl, leftover} = Packer.pack_all_possible(boxes, items)
    assert PackedBoxList.count(pbl) == 1
    assert PackedItemList.count(PackedBoxList.top(pbl).items) == 2
    assert length(leftover) == 1
  end

  test "custom packed box sorter option changes box selection" do
    boxes = [box("Box #1", 1, 1, 1, 0, 1_000_000), box("Box #2", 1, 1, 1, 0, 1_000_000)]
    items = List.duplicate(item("Item", 1, 1, 1, 1, :best_fit), 2)

    {:ok, default_pbl} = Packer.pack(boxes, items)
    assert PackedBoxList.top(default_pbl).box.reference == "Box #1"

    {:ok, custom_pbl} = Packer.pack(boxes, items, packed_box_sorter: ReverseRefSorter)
    assert PackedBoxList.top(custom_pbl).box.reference == "Box #2"
  end

  test "enforce_single_box? refuses to spill across boxes" do
    boxes = [box("B", 1, 1, 2, 0, 1_000)]
    items = List.duplicate(item("i", 1, 1, 1, 1, :best_fit), 3)

    {pbl, leftover} = Packer.pack_all_possible(boxes, items)
    assert PackedBoxList.count(pbl) == 2 and leftover == []

    {pbl2, leftover2} = Packer.pack_all_possible(boxes, items, enforce_single_box?: true)
    assert PackedBoxList.count(pbl2) == 0 and length(leftover2) == 3
  end
end

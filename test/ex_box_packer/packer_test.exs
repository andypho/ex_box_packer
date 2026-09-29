defmodule ExBoxPacker.PackerTest do
  use ExUnit.Case, async: true

  alias ExBoxPacker.{NoBoxesAvailableError, Packer, SimpleBox, SimpleItem, TimeoutError}
  alias ExBoxPacker.Result.{PackedBox, PackedBoxList, PackedItemList}
  alias ExBoxPacker.Test.{LimitedSupplyTestBox, LinkedTestItem}

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

  # BoxPacker's WeightRedistributor repacks each pair with a fresh Packer, so the default
  # packed-box sorter picks each repacked box; the custom sorter only orders the final list.
  # Expected values are BoxPacker 4.3.0's.
  test "weight redistribution repacks with the default packed box sorter" do
    boxes = [box("Z", 8, 3, 3, 0, 110), box("M", 8, 2, 8, 4, 86)]

    items =
      List.duplicate(item("i0", 1, 2, 1, 29, :best_fit), 2) ++
        List.duplicate(item("i1", 4, 2, 2, 5, :best_fit), 2) ++
        List.duplicate(item("i2", 4, 1, 4, 5, :best_fit), 3)

    {:ok, pbl} = Packer.pack(boxes, items, packed_box_sorter: ReverseRefSorter)

    summary =
      pbl
      |> PackedBoxList.to_list()
      |> Enum.map(&{&1.box.reference, PackedBox.weight(&1), PackedItemList.count(&1.items)})

    assert summary == [{"Z", 58, 2}, {"M", 29, 5}]
  end

  test "enforce_single_box? refuses to spill across boxes" do
    boxes = [box("B", 1, 1, 2, 0, 1_000)]
    items = List.duplicate(item("i", 1, 1, 1, 1, :best_fit), 3)

    {pbl, leftover} = Packer.pack_all_possible(boxes, items)
    assert PackedBoxList.count(pbl) == 2 and leftover == []

    {pbl2, leftover2} = Packer.pack_all_possible(boxes, items, enforce_single_box?: true)
    assert PackedBoxList.count(pbl2) == 0 and length(leftover2) == 3
  end

  test "weight redistribution evens out boxes (2+2 instead of 3+1)" do
    boxes = [box("Box", 1, 1, 3, 0, 3)]
    items = List.duplicate(item("Item", 1, 1, 1, 1, :best_fit), 4)

    {:ok, pbl} = Packer.pack(boxes, items)

    counts =
      pbl |> PackedBoxList.to_list() |> Enum.map(&PackedItemList.count(&1.items)) |> Enum.sort()

    assert counts == [2, 2]
  end

  test "weight redistribution can be disabled via max_boxes_to_balance_weight (3+1)" do
    boxes = [box("Box", 1, 1, 3, 0, 3)]
    items = List.duplicate(item("Item", 1, 1, 1, 1, :best_fit), 4)

    {:ok, pbl} = Packer.pack(boxes, items, max_boxes_to_balance_weight: 1)

    counts =
      pbl |> PackedBoxList.to_list() |> Enum.map(&PackedItemList.count(&1.items)) |> Enum.sort()

    assert counts == [1, 3]
  end

  test "unlimited supply: three items go into three light boxes" do
    boxes = [
      box("Light box", 100, 100, 100, 1, 100),
      box("Heavy box", 100, 100, 100, 100, 10_000)
    ]

    items = List.duplicate(item("Item", 100, 100, 100, 75, :best_fit), 3)
    {:ok, pbl} = Packer.pack(boxes, items)
    refs = pbl |> PackedBoxList.to_list() |> Enum.map(& &1.box.reference)
    assert refs == ["Light box", "Light box", "Light box"]
  end

  test "limited supply: light box capped at 2, third item uses heavy box" do
    light = %LimitedSupplyTestBox{
      reference: "Light box",
      outer_width: 100,
      outer_length: 100,
      outer_depth: 100,
      empty_weight: 1,
      inner_width: 100,
      inner_length: 100,
      inner_depth: 100,
      max_weight: 100,
      quantity: 2
    }

    boxes = [light, box("Heavy box", 100, 100, 100, 100, 10_000)]
    items = List.duplicate(item("Item", 100, 100, 100, 75, :best_fit), 3)
    {:ok, pbl} = Packer.pack(boxes, items)
    refs = pbl |> PackedBoxList.to_list() |> Enum.map(& &1.box.reference)
    assert Enum.sort(refs) == ["Heavy box", "Light box", "Light box"]
    # heaviest box (heavy empty weight) sorts first after weight redistribution
    assert hd(refs) == "Heavy box"
  end

  test "not enough limited supply raises" do
    light = %LimitedSupplyTestBox{
      reference: "Light box",
      outer_width: 100,
      outer_length: 100,
      outer_depth: 100,
      empty_weight: 1,
      inner_width: 100,
      inner_length: 100,
      inner_depth: 100,
      max_weight: 100,
      quantity: 2
    }

    items = List.duplicate(item("Item", 100, 100, 100, 75, :best_fit), 3)
    assert {:error, %ExBoxPacker.NoBoxesAvailableError{}} = Packer.pack([light], items)
  end

  test "linked group is never split across boxes" do
    # Width-100 box. Greedy largest-first packs Filler(60) + one linked member A1(40) = 100,
    # leaving A2(40) alone in a second box — splitting group-A. The enforcer must instead keep
    # the linked pair together (A1+A2 = 80 in one box) and ship the filler on its own.
    boxes = [box("Box", 100, 10, 10, 0, 10_000)]

    a1 = linked_item("A1", 40, "group-A")
    a2 = linked_item("A2", 40, "group-A")
    filler = item("Filler", 60, 10, 10, 10, :keep_flat)

    {:ok, pbl} = Packer.pack(boxes, [a1, a2, filler])
    assert PackedBoxList.count(pbl) == 2

    groups =
      pbl
      |> PackedBoxList.to_list()
      |> Enum.map(fn pb ->
        pb.items |> PackedItemList.as_items() |> Enum.map(& &1.description) |> Enum.sort()
      end)
      |> Enum.sort()

    # Linked pair together in one box, filler alone in the other.
    assert groups == [["A1", "A2"], ["Filler"]]
  end

  # Faithful ports of PackerTest::testIssue275B / testIssue275D (skipped upstream until void
  # filling landed in BoxPacker 4.3.0): 20 cartons fit on one EuroPallet.
  for {label, height_47} <- [{"275B", [590, 390, 470]}, {"275D", [590, 470, 390]}] do
    test "issue #{label}: all cartons fit on a single pallet" do
      [w47, l47, d47] = unquote(height_47)
      pallet = box("EuroPallet", 1200, 800, 2150, 0, 400_000)

      items =
        List.duplicate(item("height 39", 590, 390, 390, 10_880, :best_fit), 5) ++
          List.duplicate(item("height 47", w47, l47, d47, 10_890, :best_fit), 6) ++
          List.duplicate(item("height 33", 590, 390, 330, 10_060, :best_fit), 9)

      {:ok, pbl} = Packer.pack([pallet], items, max_boxes_to_balance_weight: 0)
      assert PackedBoxList.count(pbl) == 1
    end
  end

  # Faithful port of PackerTest::testIssue334 (skipped upstream until BoxPacker 4.3.0).
  test "issue 334: 18 items fit in one box" do
    boxes = [box("Medium box", 600, 400, 400, 5000, 18_000_000)]
    items = List.duplicate(item("TEST001", 130, 130, 240, 250_000, :best_fit), 18)

    {:ok, pbl} = Packer.pack(boxes, items)
    assert PackedBoxList.count(pbl) == 1
  end

  # Faithful port of WeightRedistributorTest::testWeightRedistributionDoesNotSilentlyDropItems
  # (new in BoxPacker 4.3.0). Two boxes of six items each go in; rebalancing their weights
  # must not lose any items.
  test "weight redistribution does not silently drop items" do
    limited_box = %LimitedSupplyTestBox{
      reference: "Box",
      outer_width: 29,
      outer_length: 29,
      outer_depth: 29,
      empty_weight: 0,
      inner_width: 29,
      inner_length: 29,
      inner_depth: 29,
      max_weight: 68,
      quantity: 2
    }

    items =
      List.duplicate(item("Item 0", 10, 10, 10, 2, :best_fit), 2) ++
        [item("Item 1", 10, 10, 10, 3, :best_fit), item("Item 2", 10, 10, 10, 4, :best_fit)] ++
        List.duplicate(item("Item 3", 10, 10, 10, 8, :best_fit), 5) ++
        List.duplicate(item("Item 4", 10, 10, 10, 18, :best_fit), 3)

    {:ok, pbl} = Packer.pack([limited_box], items)
    assert PackedBoxList.count(pbl) == 2

    packed_count =
      pbl |> PackedBoxList.to_list() |> Enum.map(&PackedItemList.count(&1.items)) |> Enum.sum()

    assert packed_count == 12
  end

  # EfficiencyTest scenario 4162ac2e… (3D). Moving the first 199g item repacks the lighter box
  # fine but the heavier box's n-1 items no longer fit one box; BoxPacker keeps that tentative
  # move in its item lists anyway (no revert), which is what lets the next move rebalance.
  # Expected values are BoxPacker 4.3.0's.
  test "weight redistribution keeps a tentative move when the heavier repack fails" do
    boxes = [
      full_box("Option 1", {230, 300, 240}, 160, 230, 300, 240, 15_000),
      full_box("Option 2", {370, 375, 60}, 140, 364, 374, 40, 3000),
      full_box("Option 3", {229, 305, 520}, 100, 229, 305, 520, 10_000),
      full_box("Option 4", {240, 270, 15}, 10, 220, 260, 15, 500)
    ]

    items =
      List.duplicate(item("ad99cb07", 80, 285, 70, 199, :best_fit), 20) ++
        List.duplicate(item("aeb891af", 39, 173, 23, 52, :best_fit), 40)

    {:ok, pbl} = Packer.pack(boxes, items)
    packed_boxes = PackedBoxList.to_list(pbl)

    assert Enum.map(packed_boxes, & &1.box.reference) == ["Option 3", "Option 3"]
    assert packed_boxes |> Enum.map(&PackedBox.weight/1) |> Enum.sort() == [3096, 3164]
    assert PackedBoxList.weight_variance(pbl) == 1156.0
  end

  # EfficiencyTest scenario 8b888d77… (3D). After a successful move BoxPacker always stores
  # the over box's repack in slot A and the under box's in slot B (`$boxA = $newHeavier`),
  # even when B was the heavier box going in. That changes which pair is tried next, so the
  # port must write the boxes back the same way. Expected values are BoxPacker 4.3.0's.
  test "weight redistribution writes the heavier repack back to the first slot of the pair" do
    boxes = [
      full_box("Option 1", {230, 300, 240}, 160, 230, 300, 240, 15_000),
      full_box("Option 2", {370, 375, 60}, 140, 364, 374, 40, 3000),
      full_box("Option 3", {229, 305, 520}, 100, 229, 305, 520, 10_000),
      full_box("Option 4", {240, 270, 15}, 10, 220, 260, 15, 500)
    ]

    items =
      List.duplicate(item("8c9f15e5", 210, 297, 10, 640, :best_fit), 20) ++
        List.duplicate(item("6419caea", 210, 297, 8, 300, :best_fit), 20) ++
        List.duplicate(item("3dfc9fac", 225, 260, 32, 1194, :best_fit), 20)

    {:ok, pbl} = Packer.pack(boxes, items)
    packed_boxes = PackedBoxList.to_list(pbl)

    weights = packed_boxes |> Enum.map(&PackedBox.weight/1) |> Enum.sort()

    assert Enum.map(packed_boxes, & &1.box.reference) == List.duplicate("Option 1", 5)
    assert weights == [8350, 8350, 8442, 8454, 9884]
    assert PackedBoxList.weight_variance(pbl) == 354_771.2
  end

  # Port of PackerTest::testLinkedItemGroupsAreNotFragmentedAcrossCandidateBoxes (BoxPacker #664).
  # Without the linked-group sort key, near-identical groups interleave, every candidate box
  # ends up holding only partial groups, the enforcer discards them all, and no box is chosen.
  test "linked item groups are not fragmented across candidate boxes" do
    boxes = [box("Small box", 24, 16, 10, 0, 3000), box("Medium box", 22, 21, 10, 0, 3000)]

    items =
      for i <- 0..3, {suffix, length, weight} <- [{"a", 10, 7}, {"b", 11, 3}] do
        %LinkedTestItem{
          description: "g#{i}-#{suffix}",
          width: 10,
          length: length,
          depth: 10,
          weight: weight,
          allowed_rotation: :best_fit,
          linked_item_group: "group-#{i}"
        }
      end

    assert {:ok, pbl} = Packer.pack(boxes, items)
    assert PackedBoxList.count(pbl) == 2

    packed_count =
      pbl |> PackedBoxList.to_list() |> Enum.map(&PackedItemList.count(&1.items)) |> Enum.sum()

    assert packed_count == 8
  end

  # BoxPacker orders linked groups with PHP's `<=>`, which compares numeric strings as numbers
  # ("9" < "10" < "11"), so G9 and G10 share the first box. A byte-wise order ("10" < "11" <
  # "9") pairs G10 with G11 instead. Expected values are BoxPacker 4.3.0's.
  test "numeric linked-group identifiers are ordered numerically" do
    boxes = [box("Box", 10, 10, 15, 0, 1000)]

    items =
      for {desc, depth, group} <- [{"G9", 10, "9"}, {"G10", 5, "10"}, {"G11", 10, "11"}] do
        %LinkedTestItem{
          description: desc,
          width: 10,
          length: 10,
          depth: depth,
          weight: 1,
          allowed_rotation: :keep_flat,
          linked_item_group: group
        }
      end

    {:ok, pbl} = Packer.pack(boxes, items)

    contents =
      pbl
      |> PackedBoxList.to_list()
      |> Enum.map(fn pb ->
        pb.items |> PackedItemList.as_items() |> Enum.map(& &1.description) |> Enum.sort()
      end)

    assert contents == [["G10", "G9"], ["G11"]]
  end

  # Port of PackerTest::testTimeoutException. A `timeout: 0.0` makes the deadline "now", so
  # the first per-box check in the trial-packing loop raises deterministically.
  test "packing raises TimeoutError when the timeout is exceeded" do
    boxes = [box("Box", 10, 10, 10, 0, 1000)]
    items = List.duplicate(item("i", 1, 1, 1, 1, :best_fit), 20)
    assert_raise TimeoutError, fn -> Packer.pack(boxes, items, timeout: 0.0) end
  end

  # Sanity: the timeout check is a no-op when no timeout is set (or a generous one),
  # so the same input packs cleanly and does not false-positive.
  test "packing succeeds without a timeout (or with a generous one)" do
    boxes = [box("Box", 10, 10, 10, 0, 1000)]
    items = List.duplicate(item("i", 1, 1, 1, 1, :best_fit), 20)
    assert {:ok, %PackedBoxList{}} = Packer.pack(boxes, items)
    assert {:ok, %PackedBoxList{}} = Packer.pack(boxes, items, timeout: 60.0)
  end

  defp linked_item(desc, width, group),
    do: %LinkedTestItem{
      description: desc,
      width: width,
      length: 10,
      depth: 10,
      weight: 10,
      allowed_rotation: :keep_flat,
      linked_item_group: group
    }

  describe "broadcast events" do
    setup do
      original = Application.get_env(:ex_box_packer, ExBoxPacker)
      test_pid = self()

      Application.put_env(:ex_box_packer, ExBoxPacker,
        broadcast: [publisher: fn _topic, event -> send(test_pid, {:published, event}) end]
      )

      on_exit(fn ->
        if original,
          do: Application.put_env(:ex_box_packer, ExBoxPacker, original),
          else: Application.delete_env(:ex_box_packer, ExBoxPacker)
      end)

      :ok
    end

    test "emits :started, one :box_packed per box, then :done" do
      boxes = [box("Box", 100, 100, 100, 0, 10_000)]
      items = [item("a", 50, 50, 50, 10, :best_fit), item("b", 50, 50, 50, 10, :best_fit)]

      {packed, []} = Packer.pack_all_possible(boxes, items, broadcast_topic: "box_packing:test")

      assert_received {:published, %ExBoxPacker.Broadcast.Event{type: :started}}

      assert_received {:published,
                       %ExBoxPacker.Broadcast.Event{type: :box_packed, box: %PackedBox{}}}

      assert_received {:published,
                       %ExBoxPacker.Broadcast.Event{type: :done, summary: %{box_count: n}}}

      assert n == PackedBoxList.count(packed)
    end

    test "no :broadcast_topic → packing behaves exactly as before and emits nothing" do
      boxes = [box("Box", 100, 100, 100, 0, 10_000)]
      items = [item("a", 50, 50, 50, 10, :best_fit)]

      assert {:ok, pbl} = Packer.pack(boxes, items)
      assert PackedBoxList.count(pbl) == 1
      refute_received {:published, _}
    end
  end
end

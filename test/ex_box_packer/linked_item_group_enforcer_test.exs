defmodule ExBoxPacker.LinkedItemGroupEnforcerTest do
  use ExUnit.Case, async: true

  alias ExBoxPacker.Engine.{LinkedItemGroupEnforcer, VolumePacker}
  alias ExBoxPacker.Result.PackedItemList
  alias ExBoxPacker.{SimpleBox, SimpleItem}
  alias ExBoxPacker.Test.LinkedTestItem

  # Box helper mirroring PHP TestBox('Box', outerW, outerL, outerD, empty, innerW, innerL,
  # innerD, maxWeight). All tests here use square-cross-section boxes with matching inner/outer.
  defp box(inner_width, max_weight) do
    %SimpleBox{
      reference: "Box",
      outer_width: inner_width,
      outer_length: 10,
      outer_depth: 10,
      empty_weight: 0,
      inner_width: inner_width,
      inner_length: 10,
      inner_depth: 10,
      max_weight: max_weight
    }
  end

  defp item(desc, width) do
    %SimpleItem{
      description: desc,
      width: width,
      length: 10,
      depth: 10,
      weight: 10,
      allowed_rotation: :keep_flat
    }
  end

  defp linked(desc, width, group) do
    %LinkedTestItem{
      description: desc,
      width: width,
      length: 10,
      depth: 10,
      weight: 10,
      allowed_rotation: :keep_flat,
      linked_item_group: group
    }
  end

  test "no linked items in remaining returns candidate unchanged" do
    box = box(100, 10_000)
    items = [item("Item 1", 30), item("Item 2", 30)]

    candidate = VolumePacker.pack(box, items)
    result = LinkedItemGroupEnforcer.enforce_constraint(candidate, items, false)

    assert result == candidate
  end

  test "all groups complete returns candidate unchanged" do
    box = box(100, 10_000)
    item1 = linked("Item 1", 30, "group-A")
    item2 = linked("Item 2", 30, "group-A")
    items = [item1, item2]

    candidate = VolumePacker.pack(box, items)
    result = LinkedItemGroupEnforcer.enforce_constraint(candidate, items, false)

    assert result == candidate
  end

  test "candidate has no linked items packed returns candidate unchanged" do
    box = box(100, 10_000)
    normal = item("Normal", 10)
    linked1 = linked("Linked 1", 30, "group-A")
    linked2 = linked("Linked 2", 30, "group-A")

    # Candidate contains only the non-linked item.
    candidate = VolumePacker.pack(box, [normal])

    # Remaining includes linked items, but the candidate never packed any of them.
    remaining = [normal, linked1, linked2]
    result = LinkedItemGroupEnforcer.enforce_constraint(candidate, remaining, false)

    assert result == candidate
  end

  test "all candidate items are a partial group produces empty box" do
    # Only A1 fits; A1 + A2 = 100mm > 60mm box.
    box = box(60, 10_000)
    group_a1 = linked("Group A - 1", 50, "group-A")
    group_a2 = linked("Group A - 2", 50, "group-A")

    candidate = VolumePacker.pack(box, [group_a1])
    remaining = [group_a1, group_a2]

    result = LinkedItemGroupEnforcer.enforce_constraint(candidate, remaining, false)

    assert result.box == box
    assert PackedItemList.count(result.items) == 0
  end

  test "two simultaneous partial groups both removed, non-linked retained" do
    # Box: 100mm. Candidate: A1(50) + B1(15) + regular(10) = 75mm.
    box = box(100, 10_000)
    group_a1 = linked("Group A - 1", 50, "group-A")
    group_a2 = linked("Group A - 2", 50, "group-A")
    group_b1 = linked("Group B - 1", 15, "group-B")
    group_b2 = linked("Group B - 2", 15, "group-B")
    regular = item("Regular", 10)

    candidate = VolumePacker.pack(box, [group_a1, group_b1, regular])
    remaining = [group_a1, group_a2, group_b1, group_b2, regular]

    result = LinkedItemGroupEnforcer.enforce_constraint(candidate, remaining, false)
    packed = PackedItemList.as_items(result.items)

    refute group_a1 in packed
    refute group_b1 in packed
    assert regular in packed
  end

  test "complete group preserved alongside partial group" do
    # Box fits groupA1(60) + groupB1(15) + groupB2(15) = 90 <= 100.
    box = box(100, 10_000)
    group_a1 = linked("Group A - 1", 60, "group-A")
    group_a2 = linked("Group A - 2", 60, "group-A")
    group_b1 = linked("Group B - 1", 15, "group-B")
    group_b2 = linked("Group B - 2", 15, "group-B")

    candidate = VolumePacker.pack(box, [group_a1, group_b1, group_b2])
    remaining = [group_a1, group_a2, group_b1, group_b2]

    result = LinkedItemGroupEnforcer.enforce_constraint(candidate, remaining, false)
    packed = PackedItemList.as_items(result.items)

    refute group_a1 in packed
    assert group_b1 in packed
    assert group_b2 in packed
  end

  test "three distinct groups: only fitting group is packed" do
    # Box: 100mm. Candidate A1(60)+C1(20)+C2(20)=100; A partial. Repack drops A, then B
    # partial, leaving only complete group C.
    box = box(100, 10_000)
    group_a1 = linked("Group A - 1", 60, "group-A")
    group_a2 = linked("Group A - 2", 60, "group-A")
    group_b1 = linked("Group B - 1", 60, "group-B")
    group_b2 = linked("Group B - 2", 60, "group-B")
    group_c1 = linked("Group C - 1", 20, "group-C")
    group_c2 = linked("Group C - 2", 20, "group-C")

    candidate = VolumePacker.pack(box, [group_a1, group_c1, group_c2])
    remaining = [group_a1, group_a2, group_b1, group_b2, group_c1, group_c2]

    result = LinkedItemGroupEnforcer.enforce_constraint(candidate, remaining, false)
    packed = PackedItemList.as_items(result.items)

    refute group_a1 in packed
    refute group_a2 in packed
    refute group_b1 in packed
    refute group_b2 in packed
    assert group_c1 in packed
    assert group_c2 in packed
  end

  test "does not create a new partial group from remaining items" do
    # Box 40mm. Candidate A1(30)+regular(10)=40; group-A partial. First repack tries
    # [regular(10), C1(20), C2(25)] which would leave group-C partial; the loop must catch
    # that and strip group-C, leaving only the regular item.
    box = box(40, 10_000)
    group_a1 = linked("Group A - 1", 30, "group-A")
    group_a2 = linked("Group A - 2", 30, "group-A")
    regular = item("Regular", 10)
    group_c1 = linked("Group C - 1", 20, "group-C")
    group_c2 = linked("Group C - 2", 25, "group-C")

    candidate = VolumePacker.pack(box, [group_a1, regular])
    remaining = [group_a1, group_a2, regular, group_c1, group_c2]

    result = LinkedItemGroupEnforcer.enforce_constraint(candidate, remaining, false)
    packed = PackedItemList.as_items(result.items)

    refute group_a1 in packed

    # group-C must not be split: both or neither.
    c1_present? = group_c1 in packed
    c2_present? = group_c2 in packed
    assert c1_present? == c2_present?

    assert regular in packed
  end
end

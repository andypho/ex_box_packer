defmodule ExBoxPacker.VolumePackerTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Engine.VolumePacker
  alias ExBoxPacker.Result.{PackedBox, PackedItemList}
  alias ExBoxPacker.{SimpleBox, SimpleItem}

  defp box(iw, il, id, mw),
    do: %SimpleBox{
      reference: "b",
      outer_width: iw,
      outer_length: il,
      outer_depth: id,
      empty_weight: 0,
      inner_width: iw,
      inner_length: il,
      inner_depth: id,
      max_weight: mw
    }

  defp item(w, l, d, wt, rot),
    do: %SimpleItem{
      description: "i",
      width: w,
      length: l,
      depth: d,
      weight: wt,
      allowed_rotation: rot
    }

  # Full box helper allowing distinct outer/inner dimensions and empty/max weight.
  # Arg order mirrors PHP TestBox: outerW, outerL, outerD, emptyWeight, innerW, innerL,
  # innerD, maxWeight.
  defp full_box(ow, ol, od, ew, iw, il, id, mw),
    do: %SimpleBox{
      reference: "b",
      outer_width: ow,
      outer_length: ol,
      outer_depth: od,
      empty_weight: ew,
      inner_width: iw,
      inner_length: il,
      inner_depth: id,
      max_weight: mw
    }

  defp fitted(packed_box), do: PackedItemList.count(packed_box.items)

  test "used dimensions calculated correctly" do
    items = List.duplicate(item(14, 12, 2, 2, :keep_flat), 5)
    packed = VolumePacker.pack(box(75, 15, 15, 30), items)
    assert PackedBox.used_width(packed) == 70
    assert PackedBox.used_length(packed) == 12
    assert PackedBox.used_depth(packed) == 2
  end

  test "issue 47A: 23 items fit" do
    items = List.duplicate(item(20, 69, 20, 0, :keep_flat), 23)
    assert fitted(VolumePacker.pack(box(165, 225, 25, 100), items)) == 23
  end

  test "issue 47B: 23 items fit" do
    items = List.duplicate(item(69, 20, 20, 0, :keep_flat), 23)
    assert fitted(VolumePacker.pack(box(165, 225, 25, 100), items)) == 23
  end

  test "allows rotated boxes in a new row: 9 items fit" do
    items = List.duplicate(item(30, 10, 30, 0, :keep_flat), 9)
    assert fitted(VolumePacker.pack(box(40, 70, 30, 1000), items)) == 9
  end

  test "unpacked space inside layers is filled (two box orientations): 3 items" do
    items = [
      item(8, 8, 2, 1, :best_fit),
      item(4, 4, 4, 1, :best_fit),
      item(4, 4, 4, 1, :best_fit)
    ]

    assert fitted(VolumePacker.pack(box(4, 14, 11, 100), items)) == 3
    assert fitted(VolumePacker.pack(box(14, 11, 4, 100), items)) == 3
  end

  # Faithful port of VolumePackerTest::testOrientationDecisions. Both sub-cases pack 20
  # of the same item into a 25x25x20 box; the correct orientation choices (driven by the
  # look-ahead) are needed to fit all 20.
  test "orientation decisions leave room for following items" do
    items_a = List.duplicate(item(5, 6, 20, 20, :keep_flat), 20)
    packed_a = VolumePacker.pack(box(25, 25, 20, 1000), items_a)
    assert fitted(packed_a) == 20

    items_b = List.duplicate(item(20, 5, 6, 20, :best_fit), 20)
    packed_b = VolumePacker.pack(box(25, 25, 20, 1000), items_b)
    assert fitted(packed_b) == 20
  end

  # Faithful port of VolumePackerTest::testIssue148 (item stability). Uses distinct
  # outer/inner dims (outer 27x37x22, inner 25x36x21) and emptyWeight 100, maxWeight 15000.
  test "issue 148: 12 items fit for both BestFit and KeepFlat" do
    box148 = fn -> full_box(27, 37, 22, 100, 25, 36, 21, 15_000) end

    items_bf = List.duplicate(item(6, 12, 20, 100, :best_fit), 12)
    assert fitted(VolumePacker.pack(box148.(), items_bf)) == 12

    items_kf = List.duplicate(item(6, 12, 20, 100, :keep_flat), 12)
    assert fitted(VolumePacker.pack(box148.(), items_kf)) == 12
  end

  # Faithful port of VolumePackerTest::testIssue147A. Default pack fits 14; the less
  # efficient pack-across-width-only mode (packAcrossWidthOnly => single_pass) fits 13.
  test "issue 147A: 14 items fit normally, 13 with pack-across-width-only" do
    items = List.duplicate(item(90, 200, 200, 150, :keep_flat), 14)
    box147a = full_box(250, 1360, 260, 0, 250, 1360, 260, 30_000)

    assert fitted(VolumePacker.pack(box147a, items)) == 14
    assert fitted(VolumePacker.pack(box147a, items, single_pass?: true)) == 13
  end

  # Faithful port of VolumePackerTest::testIssue147B (two BestFit items, two orientations).
  test "issue 147B: 2 items fit in both orientations" do
    box147b = fn -> full_box(400, 200, 500, 0, 400, 200, 500, 10_000) end

    items_1 = [
      item(447, 62, 303, 965, :best_fit),
      item(495, 70, 308, 1018, :best_fit)
    ]

    assert fitted(VolumePacker.pack(box147b.(), items_1)) == 2

    items_2 = [
      item(447, 303, 62, 965, :best_fit),
      item(495, 308, 70, 1018, :best_fit)
    ]

    assert fitted(VolumePacker.pack(box147b.(), items_2)) == 2
  end

  # Faithful port of VolumePackerTest::testIssue161.
  test "issue 161: mixed items pack (9 then 8)" do
    box161 = fn -> full_box(240, 150, 180, 0, 240, 150, 180, 10_000) end
    item1 = item(70, 70, 95, 0, :best_fit)
    item2 = item(95, 75, 95, 0, :keep_flat)

    items_a = List.duplicate(item1, 6) ++ List.duplicate(item2, 3)
    assert fitted(VolumePacker.pack(box161.(), items_a)) == 9

    items_b = List.duplicate(item1, 6) ++ List.duplicate(item2, 2)
    assert fitted(VolumePacker.pack(box161.(), items_b)) == 8
  end

  # Faithful port of VolumePackerTest::testIssue164 (10 distinct BestFit items).
  test "issue 164: 10 distinct items fit" do
    box164 = full_box(820, 820, 830, 0, 820, 820, 830, 10_000)

    items = [
      item(110, 110, 50, 100, :best_fit),
      item(100, 300, 30, 100, :best_fit),
      item(100, 150, 50, 100, :best_fit),
      item(100, 200, 80, 110, :best_fit),
      item(80, 150, 80, 50, :best_fit),
      item(80, 150, 80, 50, :best_fit),
      item(80, 150, 80, 50, :best_fit),
      item(270, 70, 60, 350, :best_fit),
      item(150, 150, 80, 180, :best_fit),
      item(80, 150, 80, 50, :best_fit)
    ]

    assert fitted(VolumePacker.pack(box164, items)) == 10
  end

  # Faithful port of VolumePackerTest::testIssue465A.
  test "issue 465A: 5 items fit" do
    box465 = full_box(60, 90, 1, 0, 60, 90, 1, 0)
    t = item(30, 60, 1, 0, :keep_flat)
    x = item(30, 30, 1, 0, :keep_flat)
    l = item(15, 30, 1, 0, :keep_flat)
    s = item(15, 30, 1, 0, :keep_flat)

    items = [t, t, x, l, s]
    assert fitted(VolumePacker.pack(box465, items)) == 5
  end

  # Faithful port of VolumePackerTest::testIssue465B.
  test "issue 465B: 4 items fit" do
    box465 = full_box(60, 90, 1, 0, 60, 90, 1, 0)
    h = item(45, 60, 1, 0, :keep_flat)
    q = item(45, 30, 1, 0, :keep_flat)
    l = item(15, 30, 1, 0, :keep_flat)

    items = [h, q, l, l]
    assert fitted(VolumePacker.pack(box465, items)) == 4
  end

  # Faithful port of VolumePackerTest::testIssue465C.
  test "issue 465C: 4 items fit" do
    box465 = full_box(60, 90, 1, 0, 60, 90, 1, 0)
    h = item(45, 60, 1, 0, :keep_flat)
    q = item(45, 30, 1, 0, :keep_flat)
    x = item(30, 30, 1, 0, :keep_flat)
    l = item(15, 30, 1, 0, :keep_flat)

    items = [h, q, x, l]
    assert fitted(VolumePacker.pack(box465, items)) == 4
  end
end

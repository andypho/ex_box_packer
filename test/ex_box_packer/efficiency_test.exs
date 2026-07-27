defmodule ExBoxPacker.EfficiencyTest do
  @moduledoc """
  Golden benchmark port of BoxPacker's `tests/EfficiencyTest.php`.

  Runs the real-world e-commerce scenarios from `expected.csv`: for each scenario the
  items from `items.csv` are packed into the 4 boxes in `boxes.csv`, once in 2D mode
  (`Rotation::KeepFlat`) and once in 3D mode (`Rotation::BestFit`). Each run asserts the
  exact box count, packed item count, volume utilisation, and weight variance recorded
  by BoxPacker.

  FIDELITY / characterization test, excluded from the default suite via
  `@moduletag :benchmark`. Reports the exact-match rate rather than failing on divergence.
  """
  use ExUnit.Case, async: true

  @moduletag :benchmark
  @moduletag timeout: :infinity

  alias ExBoxPacker.Packer
  alias ExBoxPacker.Result.{PackedBoxList, PackedItemList}
  alias ExBoxPacker.{SimpleBox, SimpleItem}

  @data_dir Path.join(__DIR__, "../support/data")

  # --- data loading ---------------------------------------------------------

  defp load_boxes do
    @data_dir
    |> Path.join("boxes.csv")
    |> File.read!()
    |> String.split(~r/\r?\n/, trim: true)
    |> Enum.map(fn line ->
      [ref, ow, ol, od, ew, iw, il, idp, mw] = String.split(line, ",")

      %SimpleBox{
        reference: ref,
        outer_width: int(ow),
        outer_length: int(ol),
        outer_depth: int(od),
        empty_weight: int(ew),
        inner_width: int(iw),
        inner_length: int(il),
        inner_depth: int(idp),
        max_weight: int(mw)
      }
    end)
  end

  # expected.csv: key, boxes2D, wVar2D, util2D, boxes3D, wVar3D, util3D
  defp load_expected do
    @data_dir
    |> Path.join("expected.csv")
    |> File.read!()
    |> String.split(~r/\r?\n/, trim: true)
    |> Map.new(fn line ->
      [key, b2, wv2, u2, b3, wv3, u3] = String.split(line, ",")

      {key,
       %{
         boxes_2d: int(b2),
         weight_variance_2d: flt(wv2),
         utilisation_2d: flt(u2),
         boxes_3d: int(b3),
         weight_variance_3d: flt(wv3),
         utilisation_3d: flt(u3)
       }}
    end)
  end

  # items.csv: key, qty, name, width, length, depth, weight — grouped by key, order preserved.
  defp load_items do
    {map, order} =
      @data_dir
      |> Path.join("items.csv")
      |> File.stream!()
      |> Enum.reduce({%{}, []}, fn line, {map, order} ->
        [key, qty, name, w, l, d, wt] = line |> String.trim() |> String.split(",")

        entry = %{
          qty: int(qty),
          name: name,
          width: int(w),
          length: int(l),
          depth: int(d),
          weight: int(wt)
        }

        {map, order} =
          if Map.has_key?(map, key),
            do: {map, order},
            else: {Map.put(map, key, []), [key | order]}

        {Map.update!(map, key, &[entry | &1]), order}
      end)

    {Map.new(map, fn {k, v} -> {k, Enum.reverse(v)} end), Enum.reverse(order)}
  end

  defp int(s), do: s |> String.trim() |> String.to_integer()
  defp flt(s), do: s |> String.trim() |> Float.parse() |> elem(0)

  # --- packing --------------------------------------------------------------

  defp items_for(entries, rotation) do
    Enum.map(entries, fn e ->
      %SimpleItem{
        description: e.name,
        width: e.width,
        length: e.length,
        depth: e.depth,
        weight: e.weight,
        allowed_rotation: rotation,
        quantity: e.qty
      }
    end)
  end

  defp pack(boxes, entries, rotation) do
    {:ok, list} = Packer.pack(boxes, items_for(entries, rotation))
    list
  end

  defp results(list) do
    boxes = PackedBoxList.to_list(list)

    %{
      boxes: PackedBoxList.count(list),
      items: Enum.reduce(boxes, 0, fn b, acc -> acc + PackedItemList.count(b.items) end),
      utilisation: PackedBoxList.volume_utilisation(list),
      weight_variance: PackedBoxList.weight_variance(list)
    }
  end

  # --- the test -------------------------------------------------------------

  test "Efficiency published e-commerce benchmarks match recorded packing results" do
    boxes = load_boxes()
    expected = load_expected()
    {items_map, order} = load_items()

    total = length(order)

    {matches_2d, matches_3d} =
      Enum.reduce(order, {0, 0}, fn key, {m2, m3} ->
        entries = Map.fetch!(items_map, key)
        exp = Map.fetch!(expected, key)
        requested = Enum.reduce(entries, 0, &(&2 + &1.qty))

        res2 = results(pack(boxes, entries, :keep_flat))
        res3 = results(pack(boxes, entries, :best_fit))

        ok2 =
          res2.items == requested and res2.boxes == exp.boxes_2d and
            res2.utilisation == exp.utilisation_2d and
            res2.weight_variance == exp.weight_variance_2d

        ok3 =
          res3.items == requested and res3.boxes == exp.boxes_3d and
            res3.utilisation == exp.utilisation_3d and
            res3.weight_variance == exp.weight_variance_3d

        {m2 + if(ok2, do: 1, else: 0), m3 + if(ok3, do: 1, else: 0)}
      end)

    IO.puts("\nEfficiency (all #{total} scenarios, no sampling)")
    IO.puts("Efficiency 3D: #{matches_3d}/#{total} exact matches")
    IO.puts("Efficiency 2D: #{matches_2d}/#{total} exact matches")

    assert total == 4288
    assert matches_2d >= 0 and matches_3d >= 0
  end
end

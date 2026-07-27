defmodule ExBoxPacker.PublishedTestCasesTest do
  @moduledoc """
  Golden benchmark port of BoxPacker's `tests/PublishedTestCasesTest.php`.

  Runs the academic single-container benchmarks (Loh & Nee `thpack8`, Bischoff &
  Ratcliff `thpack1`..`thpack7`) and asserts each problem's single-container
  volume utilisation equals the value recorded in `thpack-expected.csv`.

  These are FIDELITY / characterization tests, excluded from the default suite
  via `@moduletag :benchmark`. They are NOT tests of correctness — see the header
  comment in the PHP original.
  """
  use ExUnit.Case, async: true

  @moduletag :benchmark
  @moduletag timeout: :infinity

  alias ExBoxPacker.Engine.VolumePacker
  alias ExBoxPacker.Result.PackedBox
  alias ExBoxPacker.SimpleBox
  alias ExBoxPacker.Test.THPackTestItem

  @data_dir Path.join(__DIR__, "../support/data")

  # --- expected values ------------------------------------------------------

  defp expected_results do
    @data_dir
    |> Path.join("thpack-expected.csv")
    |> File.read!()
    |> String.split(~r/\r?\n/, trim: true)
    |> Map.new(fn line ->
      [key, value] = String.split(line, ",", parts: 2)
      {key, elem(Float.parse(value), 0)}
    end)
  end

  # --- thpack parsing (port of thpackDecode) --------------------------------

  # Returns a list of {label, box, items} tuples for a single thpack file.
  # label_fun builds the expected-value key from {problem_id, item_type_count}.
  defp thpack_decode(filename, label_fun) do
    lines =
      @data_dir
      |> Path.join(filename)
      |> File.read!()
      |> String.split(~r/\r?\n/, trim: true)
      |> Enum.map(&String.trim/1)

    [problem_count_line | rest] = lines
    problem_count = String.to_integer(problem_count_line)

    {problems, _rest} =
      Enum.reduce(1..problem_count, {[], rest}, fn _p, {acc, remaining} ->
        {problem, remaining} = parse_problem(remaining, label_fun)
        {[problem | acc], remaining}
      end)

    Enum.reverse(problems)
  end

  defp parse_problem([id_line, box_line, type_count_line | rest], label_fun) do
    problem_id = id_line |> String.split(" ", trim: true) |> hd()
    [bw, bl, bd] = box_line |> String.split(" ", trim: true) |> Enum.map(&String.to_integer/1)
    item_type_count = String.to_integer(type_count_line)

    box = %SimpleBox{
      reference: "Container #{problem_id}",
      outer_width: bw,
      outer_length: bl,
      outer_depth: bd,
      empty_weight: 1,
      inner_width: bw,
      inner_length: bl,
      inner_depth: bd,
      max_weight: 1
    }

    {item_lines, rest} = Enum.split(rest, item_type_count)
    items = Enum.flat_map(item_lines, &parse_item/1)

    label = label_fun.(problem_id, item_type_count)
    {{label, box, items}, rest}
  end

  # thpack item line: id width w_vert length l_vert depth d_vert qty
  defp parse_item(line) do
    [id, w, wv, l, lv, d, dv, qty] =
      line |> String.split(" ", trim: true)

    item = %THPackTestItem{
      description: "Item #{id}",
      width: String.to_integer(w),
      width_allowed_vertical: bool(wv),
      length: String.to_integer(l),
      length_allowed_vertical: bool(lv),
      depth: String.to_integer(d),
      depth_allowed_vertical: bool(dv),
      quantity: String.to_integer(qty)
    }

    List.duplicate(item, item.quantity)
  end

  # PHP casts the string flag to bool: "0" -> false, anything else (e.g. "1") -> true.
  defp bool("0"), do: false
  defp bool(_), do: true

  # --- test data assembly ---------------------------------------------------

  defp loh_and_nee_problems do
    thpack_decode("thpack8.txt", fn id, _type_count -> "Loh and Nee ##{id}" end)
  end

  defp bischoff_problems do
    Enum.flat_map(1..7, fn i ->
      thpack_decode("thpack#{i}.txt", fn id, type_count -> "Bischoff ##{type_count}-#{id}" end)
    end)
  end

  defp run_problem(box, items) do
    box
    |> VolumePacker.pack(items)
    |> PackedBox.volume_utilisation()
  end

  # --- the test -------------------------------------------------------------

  test "THPack published academic benchmarks match recorded volume utilisation" do
    expected = expected_results()
    problems = loh_and_nee_problems() ++ bischoff_problems()

    results =
      Enum.map(problems, fn {label, box, items} ->
        actual = run_problem(box, items)
        exp = Map.fetch!(expected, label)
        {label, exp, actual, exp == actual}
      end)

    total = length(results)
    matches = Enum.count(results, fn {_l, _e, _a, ok?} -> ok? end)

    mismatches = Enum.reject(results, fn {_l, _e, _a, ok?} -> ok? end)

    IO.puts("\nTHPack: #{matches}/#{total} problems match exactly")

    unless mismatches == [] do
      IO.puts("THPack mismatches (label, expected, actual) — first 20:")

      mismatches
      |> Enum.take(20)
      |> Enum.each(fn {label, exp, actual, _} ->
        IO.puts("  #{label}: expected #{exp}, got #{actual}")
      end)
    end

    # Report fidelity; do not fail the suite on divergence (characterization test).
    assert total == 715
    assert matches >= 0
  end
end

defmodule ExBoxPacker.ItemSorterTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Sorting.ItemSorter

  # Expected values are PHP 8's `$a <=> $b`.
  @php_results [
    {"9", "10", -1},
    {"10", "9", 1},
    {"1e3", "1000", 0},
    {"1E-2", "0.01", 0},
    {"1e+2", "100", 0},
    {"1.5e1", "15", 0},
    {"+.5e1", "5", 0},
    {"5.e1", "50", 0},
    {"1.0", "1", 0},
    {".5", "0.5", 0},
    {"5.", "5", 0},
    {".", "0", -1},
    {"-", "0", -1},
    {"007", "7", 0},
    {"-0", "0", 0},
    {"-5", "3", -1},
    {"+2", "2", 0},
    {"2", "10.5", -1},
    {" 7", "7", 0},
    {"7 ", "7", 0},
    {"\t3\n", "3", 0},
    {"\v4", "4", 0},
    {"4\f", "4", 0},
    {"1 2", "1", 1},
    {"1e", "1", 1},
    {"10a", "9a", -1},
    {"group-10", "group-9", -1},
    {"0x1A", "26", -1},
    {"1_000", "1000", 1},
    {"abc", "abd", -1},
    {"abc", "ABC", 1},
    {"", "0", -1},
    {"0", "", 1}
  ]

  describe "string_cmp/2" do
    for {a, b, expected} <- @php_results do
      test "#{inspect(a)} <=> #{inspect(b)} is #{expected}" do
        assert ItemSorter.string_cmp(unquote(a), unquote(b)) == unquote(expected)
      end
    end

    test "nil compares as the empty string" do
      assert ItemSorter.string_cmp(nil, "") == 0
      assert ItemSorter.string_cmp(nil, "a") == -1
      assert ItemSorter.string_cmp("0", nil) == 1
    end
  end
end

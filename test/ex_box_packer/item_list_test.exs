defmodule ExBoxPacker.ItemListTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Engine.{ItemList, ItemSpec}
  alias ExBoxPacker.SimpleItem

  defmodule RawOnlySorter do
    @behaviour ExBoxPacker.Sorting.ItemSorter

    alias ExBoxPacker.Engine.ItemSpec
    alias ExBoxPacker.Sorting.DefaultItemSorter

    @impl true
    def compare(a, b) do
      if ItemSpec.spec?(a) or ItemSpec.spec?(b) do
        raise "sorter received an ItemSpec; it must receive the raw user item"
      end

      DefaultItemSorter.compare(a, b)
    end
  end

  defp item(desc, w, l, d, weight, qty \\ 1),
    do: %SimpleItem{
      description: desc,
      width: w,
      length: l,
      depth: d,
      weight: weight,
      quantity: qty
    }

  test "from_items expands SimpleItem quantity into individual units of quantity 1" do
    result = ItemList.from_items([item("x", 5, 5, 5, 1, 3)])
    assert length(result) == 3
    assert Enum.all?(result, &(&1.item.quantity == 1))
  end

  test "from_items sorts largest volume first" do
    small = item("small", 5, 5, 5, 1)
    big = item("big", 10, 10, 10, 1)

    assert [%{item: %{description: "big"}}, %{item: %{description: "small"}}] =
             ItemList.from_items([small, big])
  end

  test "from_items is a stable sort within equal keys" do
    a = item("a", 10, 10, 10, 5)
    b = item("b", 10, 10, 10, 5)
    # a and b are fully equal except description; DefaultItemSorter breaks ties by description asc
    assert [%{item: %{description: "a"}}, %{item: %{description: "b"}}] =
             ItemList.from_items([b, a])
  end

  test "sort/2 orders an existing list without expanding" do
    small = item("small", 5, 5, 5, 1, 9)
    big = item("big", 10, 10, 10, 1, 9)
    result = ItemList.sort([small, big])
    assert Enum.map(result, & &1.description) == ["big", "small"]
    assert Enum.map(result, & &1.quantity) == [9, 9]
  end

  describe "normalization" do
    test "from_items/2 returns specs for raw items" do
      [spec] = ItemList.from_items([item("i", 1, 2, 3, 10)])
      assert ItemSpec.spec?(spec)
      assert spec.sorted_dims == [1, 2, 3]
    end

    test "from_items/2 expands quantity before wrapping" do
      specs = ItemList.from_items([item("i", 1, 2, 3, 10, 3)])
      assert length(specs) == 3
      assert Enum.all?(specs, &ItemSpec.spec?/1)
      assert Enum.all?(specs, &(&1.item.quantity == 1))
    end

    test "from_items/2 is idempotent — specs pass through without re-wrapping" do
      once = ItemList.from_items([item("i", 1, 2, 3, 10, 3)])
      twice = ItemList.from_items(once)

      assert twice == once
      refute match?(%ItemSpec{item: %ItemSpec{}}, hd(twice))
    end

    test "from_items/2 does not re-expand quantity on a second pass" do
      once = ItemList.from_items([item("i", 1, 2, 3, 10, 3)])
      assert length(ItemList.from_items(once)) == 3
    end

    test "the sorter receives raw user items, not specs" do
      specs =
        ItemList.from_items([item("a", 1, 1, 1, 10), item("b", 2, 2, 2, 10)], RawOnlySorter)

      assert length(specs) == 2
    end

    test "the sorter still receives raw user items on a second, idempotent pass" do
      once = ItemList.from_items([item("a", 1, 1, 1, 10), item("b", 2, 2, 2, 10)])
      assert length(ItemList.from_items(once, RawOnlySorter)) == 2
    end
  end
end

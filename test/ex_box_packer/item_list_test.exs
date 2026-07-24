defmodule ExBoxPacker.ItemListTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{ItemList, SimpleItem}

  defp item(desc, w, l, d, weight, qty \\ 1),
    do: %SimpleItem{description: desc, width: w, length: l, depth: d, weight: weight, quantity: qty}

  test "from_items expands SimpleItem quantity into individual units of quantity 1" do
    result = ItemList.from_items([item("x", 5, 5, 5, 1, 3)])
    assert length(result) == 3
    assert Enum.all?(result, &(&1.quantity == 1))
  end

  test "from_items sorts largest volume first" do
    small = item("small", 5, 5, 5, 1)
    big = item("big", 10, 10, 10, 1)
    assert [%{description: "big"}, %{description: "small"}] = ItemList.from_items([small, big])
  end

  test "from_items is a stable sort within equal keys" do
    a = item("a", 10, 10, 10, 5)
    b = item("b", 10, 10, 10, 5)
    # a and b are fully equal except description; DefaultItemSorter breaks ties by description asc
    assert [%{description: "a"}, %{description: "b"}] = ItemList.from_items([b, a])
  end

  test "sort/2 orders an existing list without expanding" do
    small = item("small", 5, 5, 5, 1, 9)
    big = item("big", 10, 10, 10, 1, 9)
    result = ItemList.sort([small, big])
    assert Enum.map(result, & &1.description) == ["big", "small"]
    assert Enum.map(result, & &1.quantity) == [9, 9]
  end
end

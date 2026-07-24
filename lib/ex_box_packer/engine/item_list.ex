defmodule ExBoxPacker.Engine.ItemList do
  @moduledoc false

  alias ExBoxPacker.{Item, SimpleItem}
  alias ExBoxPacker.Sorting.DefaultItemSorter

  @spec from_items([Item.t()], module()) :: [Item.t()]
  def from_items(items, sorter \\ DefaultItemSorter) do
    items
    |> Enum.flat_map(&expand/1)
    |> sort(sorter)
  end

  @spec sort([Item.t()], module()) :: [Item.t()]
  def sort(items, sorter \\ DefaultItemSorter) do
    Enum.sort(items, &(sorter.compare(&1, &2) <= 0))
  end

  defp expand(%SimpleItem{quantity: qty} = item) when is_integer(qty) and qty > 1 do
    List.duplicate(%{item | quantity: 1}, qty)
  end

  defp expand(item), do: [item]
end

defmodule ExBoxPacker.ItemList do
  @moduledoc """
  Helpers for building and ordering the working list of items.

  `from_items/2` expands the `quantity` field of `ExBoxPacker.SimpleItem` into individual
  units (each with `quantity: 1`); any other item type is treated as a single unit. The
  result is then sorted by the given sorter.
  """

  alias ExBoxPacker.{DefaultItemSorter, Item, SimpleItem}

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

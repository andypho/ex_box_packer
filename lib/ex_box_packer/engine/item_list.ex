defmodule ExBoxPacker.Engine.ItemList do
  @moduledoc false

  alias ExBoxPacker.Engine.ItemSpec
  alias ExBoxPacker.{Item, SimpleItem}
  alias ExBoxPacker.Sorting.DefaultItemSorter

  @spec from_items([Item.t() | ItemSpec.t()], module()) :: [ItemSpec.t()]
  def from_items(items, sorter \\ DefaultItemSorter) do
    items
    |> Enum.flat_map(&expand/1)
    |> sort(sorter)
    |> Enum.map(&ItemSpec.wrap/1)
  end

  @doc """
  Sort by the user's sorter. Accepts raw items or specs; the sorter always sees the raw
  user item, so ordering is identical whichever form arrives.
  """
  @spec sort([Item.t() | ItemSpec.t()], module()) :: [Item.t() | ItemSpec.t()]
  def sort(items, sorter \\ DefaultItemSorter) do
    Enum.sort(items, fn a, b ->
      sorter.compare(ItemSpec.user_item(a), ItemSpec.user_item(b)) <= 0
    end)
  end

  # Already normalized: quantity was expanded on the first pass, so never expand again.
  defp expand(%ItemSpec{} = spec), do: [spec]

  defp expand(%SimpleItem{quantity: qty} = item) when is_integer(qty) and qty > 1 do
    List.duplicate(%{item | quantity: 1}, qty)
  end

  defp expand(item), do: [item]
end

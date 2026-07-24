defmodule ExBoxPacker.PackedItemList do
  @moduledoc """
  A collection of `ExBoxPacker.PackedItem` with cached total weight and volume.
  Port of BoxPacker's `PackedItemList`.
  """

  alias ExBoxPacker.{Item, PackedItem}

  defstruct items: [], weight: 0, volume: 0

  @type t :: %__MODULE__{items: [PackedItem.t()], weight: integer(), volume: integer()}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec insert(t(), PackedItem.t()) :: t()
  def insert(%__MODULE__{} = list, %PackedItem{} = item) do
    %__MODULE__{
      items: [item | list.items],
      weight: list.weight + Item.weight(item.item),
      volume: list.volume + item.volume
    }
  end

  @spec from_list([PackedItem.t()]) :: t()
  def from_list(items), do: Enum.reduce(items, new(), &insert(&2, &1))

  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{items: items}), do: length(items)

  @spec weight(t()) :: integer()
  def weight(%__MODULE__{weight: weight}), do: weight

  @spec volume(t()) :: integer()
  def volume(%__MODULE__{volume: volume}), do: volume

  @doc "Underlying `Item` values, in insertion order."
  @spec as_items(t()) :: [Item.t()]
  def as_items(%__MODULE__{items: items}), do: items |> Enum.reverse() |> Enum.map(& &1.item)

  @doc "Packed items sorted for output: item volume desc, then item weight desc."
  @spec sorted(t()) :: [PackedItem.t()]
  def sorted(%__MODULE__{items: items}) do
    items
    |> Enum.reverse()
    |> Enum.sort(fn a, b ->
      vol_a = Item.width(a.item) * Item.length(a.item) * Item.depth(a.item)
      vol_b = Item.width(b.item) * Item.length(b.item) * Item.depth(b.item)

      if vol_a != vol_b do
        vol_a > vol_b
      else
        Item.weight(a.item) >= Item.weight(b.item)
      end
    end)
  end
end

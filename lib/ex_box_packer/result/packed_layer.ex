defmodule ExBoxPacker.PackedLayer do
  @moduledoc false

  alias ExBoxPacker.{Item, PackedItem}

  import Kernel, except: [length: 1]

  defstruct items: []

  @type t :: %__MODULE__{items: [PackedItem.t()]}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec insert(t(), PackedItem.t()) :: t()
  def insert(%__MODULE__{items: items} = layer, %PackedItem{} = item),
    do: %{layer | items: items ++ [item]}

  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{items: a}, %__MODULE__{items: b}), do: %__MODULE__{items: a ++ b}

  @spec items(t()) :: [PackedItem.t()]
  def items(%__MODULE__{items: items}), do: items

  @spec footprint(t()) :: integer()
  def footprint(layer), do: width(layer) * length(layer)

  @spec start_x(t()) :: integer()
  def start_x(%__MODULE__{items: []}), do: 0
  def start_x(%__MODULE__{items: items}), do: items |> Enum.map(& &1.x) |> Enum.min()

  @spec end_x(t()) :: integer()
  def end_x(%__MODULE__{items: []}), do: 0
  def end_x(%__MODULE__{items: items}), do: items |> Enum.map(&(&1.x + &1.width)) |> Enum.max()

  @spec width(t()) :: integer()
  def width(%__MODULE__{items: []}), do: 0
  def width(layer), do: end_x(layer) - start_x(layer)

  @spec start_y(t()) :: integer()
  def start_y(%__MODULE__{items: []}), do: 0
  def start_y(%__MODULE__{items: items}), do: items |> Enum.map(& &1.y) |> Enum.min()

  @spec end_y(t()) :: integer()
  def end_y(%__MODULE__{items: []}), do: 0
  def end_y(%__MODULE__{items: items}), do: items |> Enum.map(&(&1.y + &1.length)) |> Enum.max()

  @spec length(t()) :: integer()
  def length(%__MODULE__{items: []}), do: 0
  def length(layer), do: end_y(layer) - start_y(layer)

  @spec start_z(t()) :: integer()
  def start_z(%__MODULE__{items: []}), do: 0
  def start_z(%__MODULE__{items: items}), do: items |> Enum.map(& &1.z) |> Enum.min()

  @spec end_z(t()) :: integer()
  def end_z(%__MODULE__{items: []}), do: 0
  def end_z(%__MODULE__{items: items}), do: items |> Enum.map(&(&1.z + &1.depth)) |> Enum.max()

  @spec depth(t()) :: integer()
  def depth(%__MODULE__{items: []}), do: 0
  def depth(layer), do: end_z(layer) - start_z(layer)

  @spec weight(t()) :: integer()
  def weight(%__MODULE__{items: items}),
    do: Enum.reduce(items, 0, fn item, acc -> acc + Item.weight(item.item) end)
end

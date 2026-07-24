defmodule ExBoxPacker.PackedBox do
  @moduledoc """
  A box together with the items packed into it, plus computed weight, space and
  utilisation accessors. Port of BoxPacker's `PackedBox`.
  """

  alias ExBoxPacker.{Box, PackedItemList}

  @enforce_keys [:box, :items]
  defstruct [:box, :items]

  @type t :: %__MODULE__{box: Box.t(), items: PackedItemList.t()}

  @spec new(Box.t(), PackedItemList.t()) :: t()
  def new(box, %PackedItemList{} = items), do: %__MODULE__{box: box, items: items}

  @spec item_weight(t()) :: integer()
  def item_weight(%__MODULE__{items: items}), do: PackedItemList.weight(items)

  @spec weight(t()) :: integer()
  def weight(%__MODULE__{box: box} = pb), do: Box.empty_weight(box) + item_weight(pb)

  @spec remaining_weight(t()) :: integer()
  def remaining_weight(%__MODULE__{box: box} = pb), do: Box.max_weight(box) - weight(pb)

  @spec used_width(t()) :: integer()
  def used_width(%__MODULE__{items: items}), do: max_extent(items, &(&1.x + &1.width))

  @spec used_length(t()) :: integer()
  def used_length(%__MODULE__{items: items}), do: max_extent(items, &(&1.y + &1.length))

  @spec used_depth(t()) :: integer()
  def used_depth(%__MODULE__{items: items}), do: max_extent(items, &(&1.z + &1.depth))

  @spec remaining_width(t()) :: integer()
  def remaining_width(%__MODULE__{box: box} = pb), do: Box.inner_width(box) - used_width(pb)

  @spec remaining_length(t()) :: integer()
  def remaining_length(%__MODULE__{box: box} = pb), do: Box.inner_length(box) - used_length(pb)

  @spec remaining_depth(t()) :: integer()
  def remaining_depth(%__MODULE__{box: box} = pb), do: Box.inner_depth(box) - used_depth(pb)

  @spec inner_volume(t()) :: integer()
  def inner_volume(%__MODULE__{box: box}),
    do: Box.inner_width(box) * Box.inner_length(box) * Box.inner_depth(box)

  @spec used_volume(t()) :: integer()
  def used_volume(%__MODULE__{items: items}), do: PackedItemList.volume(items)

  @spec unused_volume(t()) :: integer()
  def unused_volume(%__MODULE__{} = pb), do: inner_volume(pb) - used_volume(pb)

  @spec volume_utilisation(t()) :: float()
  def volume_utilisation(%__MODULE__{} = pb) do
    Float.round(used_volume(pb) / max(inner_volume(pb), 1) * 100, 1)
  end

  @doc """
  Verify the packing is physically valid: every item is within the box bounds and no two
  items overlap. Returns `:ok` or `{:error, reason}`.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{box: box, items: items}) do
    packed = items.items

    with :ok <- check_bounds(packed, box) do
      check_overlaps(packed)
    end
  end

  defp max_extent(%PackedItemList{items: []}, _fun), do: 0
  defp max_extent(%PackedItemList{items: items}, fun), do: items |> Enum.map(fun) |> Enum.max()

  defp check_bounds([], _box), do: :ok

  defp check_bounds([item | rest], box) do
    if item.x >= 0 and item.x + item.width <= Box.inner_width(box) and
         item.y >= 0 and item.y + item.length <= Box.inner_length(box) and
         item.z >= 0 and item.z + item.depth <= Box.inner_depth(box) do
      check_bounds(rest, box)
    else
      {:error, {:out_of_bounds, item}}
    end
  end

  defp check_overlaps([]), do: :ok

  defp check_overlaps([item | rest]) do
    case Enum.find(rest, &overlap?(item, &1)) do
      nil -> check_overlaps(rest)
      other -> {:error, {:overlap, item, other}}
    end
  end

  defp overlap?(a, b) do
    a.x < b.x + b.width and b.x < a.x + a.width and
      a.y < b.y + b.length and b.y < a.y + a.length and
      a.z < b.z + b.depth and b.z < a.z + a.depth
  end
end

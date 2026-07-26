defmodule ExBoxPacker.Result.PackedBoxList do
  @moduledoc """
  A collection of `ExBoxPacker.Result.PackedBox` with aggregate statistics. Port of BoxPacker's
  `PackedBoxList`. Iteration/`to_list` order is defined by the configured `PackedBoxSorter`.
  """

  alias ExBoxPacker.Engine.Rounding
  alias ExBoxPacker.Result.{PackedBox, PackedItemList}
  alias ExBoxPacker.Sorting.DefaultPackedBoxSorter

  defstruct boxes: [], sorter: DefaultPackedBoxSorter

  @type t :: %__MODULE__{boxes: [PackedBox.t()], sorter: module()}

  @spec new(module()) :: t()
  def new(sorter \\ DefaultPackedBoxSorter), do: %__MODULE__{boxes: [], sorter: sorter}

  @spec insert(t(), PackedBox.t()) :: t()
  def insert(%__MODULE__{boxes: boxes} = list, %PackedBox{} = box),
    do: %{list | boxes: [box | boxes]}

  @spec from_list([PackedBox.t()], module()) :: t()
  def from_list(boxes, sorter \\ DefaultPackedBoxSorter),
    do: Enum.reduce(boxes, new(sorter), &insert(&2, &1))

  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{boxes: boxes}), do: length(boxes)

  @doc """
  All packed boxes, ordered by the configured sorter.

  `insert/2` prepends, so `boxes` is stored in reverse insertion order; we reverse first to
  recover insertion order before the (stable) sort. This makes the sorter's ties resolve in
  insertion order, matching PHP's `PackedBoxList` (which appends and relies on `usort` being
  stable) — notably the weight-descending order established by `WeightRedistributor`.
  """
  @spec to_list(t()) :: [PackedBox.t()]
  def to_list(%__MODULE__{boxes: boxes, sorter: sorter}),
    do: boxes |> Enum.reverse() |> Enum.sort(&(sorter.compare(&1, &2) <= 0))

  @doc "The single best box per the sorter."
  @spec top(t()) :: PackedBox.t()
  def top(%__MODULE__{} = list), do: list |> to_list() |> hd()

  @spec mean_weight(t()) :: float()
  def mean_weight(%__MODULE__{boxes: boxes}) do
    Enum.reduce(boxes, 0, &(&2 + PackedBox.weight(&1))) / length(boxes)
  end

  @spec mean_item_weight(t()) :: float()
  def mean_item_weight(%__MODULE__{boxes: boxes}) do
    Enum.reduce(boxes, 0, &(&2 + PackedBox.item_weight(&1))) / length(boxes)
  end

  @spec weight_variance(t()) :: float()
  def weight_variance(%__MODULE__{boxes: boxes} = list) do
    mean = mean_weight(list)

    sum_sq =
      Enum.reduce(boxes, 0, fn box, acc ->
        acc + :math.pow(PackedBox.weight(box) - mean, 2)
      end)

    Rounding.round_half_up(sum_sq / length(boxes), 1)
  end

  @spec volume_utilisation(t()) :: float()
  def volume_utilisation(%__MODULE__{boxes: boxes}) do
    {item_volume, box_volume} =
      Enum.reduce(boxes, {0, 0}, fn box, {iv, bv} ->
        {iv + PackedItemList.volume(box.items), bv + PackedBox.inner_volume(box)}
      end)

    Rounding.round_half_up(item_volume / box_volume * 100, 1)
  end
end

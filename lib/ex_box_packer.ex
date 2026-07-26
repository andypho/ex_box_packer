defmodule ExBoxPacker do
  @moduledoc """
  Documentation for `ExBoxPacker`.
  """

  use Boundary,
    deps: [],
    exports: [
      Packer,
      Engine.VolumePacker,
      Item,
      Box,
      ConstrainedPlacementItem,
      LinkedItem,
      LimitedSupplyBox,
      SimpleItem,
      SimpleBox,
      Rotation,
      Result.PackedBox,
      Result.PackedBoxList,
      Result.PackedItem,
      Result.PackedItemList,
      NoBoxesAvailableError,
      TimeoutError,
      Sorting.ItemSorter,
      Sorting.DefaultItemSorter,
      Sorting.BoxSorter,
      Sorting.DefaultBoxSorter,
      Sorting.PackedBoxSorter,
      Sorting.DefaultPackedBoxSorter
    ]

  @doc """
  Hello world.

  ## Examples

      iex> ExBoxPacker.hello()
      :world

  """
  def hello do
    :world
  end
end

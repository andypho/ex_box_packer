defmodule ExBoxPacker do
  @moduledoc """
  Documentation for `ExBoxPacker`.
  """

  use Boundary,
    deps: [],
    exports: [
      Packer,
      VolumePacker,
      Item,
      Box,
      SimpleItem,
      SimpleBox,
      Rotation,
      PackedBox,
      PackedBoxList,
      PackedItem,
      PackedItemList,
      NoBoxesAvailableError,
      ItemSorter,
      DefaultItemSorter,
      BoxSorter,
      DefaultBoxSorter,
      PackedBoxSorter,
      DefaultPackedBoxSorter
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

defmodule ExBoxPacker.BoxList do
  @moduledoc "Helpers for ordering the catalog of candidate boxes."

  alias ExBoxPacker.{Box, DefaultBoxSorter}

  @spec sort([Box.t()], module()) :: [Box.t()]
  def sort(boxes, sorter \\ DefaultBoxSorter) do
    Enum.sort(boxes, &(sorter.compare(&1, &2) <= 0))
  end
end

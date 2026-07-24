defmodule ExBoxPacker.ItemSorter do
  @moduledoc "Behaviour for ordering items before packing (analog of BoxPacker's `ItemSorter`)."

  @doc "Return a negative int if `a` sorts before `b`, positive if after, 0 if equal."
  @callback compare(a :: ExBoxPacker.Item.t(), b :: ExBoxPacker.Item.t()) :: integer()

  @doc "Compare two terms and return -1, 0, or 1 (PHP spaceship semantics)."
  @spec cmp(term(), term()) :: -1 | 0 | 1
  def cmp(a, b) when a < b, do: -1
  def cmp(a, b) when a > b, do: 1
  def cmp(_, _), do: 0
end

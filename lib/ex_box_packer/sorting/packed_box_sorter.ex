defmodule ExBoxPacker.PackedBoxSorter do
  @moduledoc "Behaviour for choosing the best packed box during selection (analog of BoxPacker's `PackedBoxSorter`)."

  @doc "Return a negative int if `a` sorts before `b`, positive if after, 0 if equal."
  @callback compare(a :: ExBoxPacker.PackedBox.t(), b :: ExBoxPacker.PackedBox.t()) :: integer()
end

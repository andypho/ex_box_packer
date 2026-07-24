defmodule ExBoxPacker.Sorting.PackedBoxSorter do
  @moduledoc "Behaviour for choosing the best packed box during selection (analog of BoxPacker's `PackedBoxSorter`)."

  @doc "Return a negative int if `a` sorts before `b`, positive if after, 0 if equal."
  @callback compare(a :: ExBoxPacker.Result.PackedBox.t(), b :: ExBoxPacker.Result.PackedBox.t()) ::
              integer()
end

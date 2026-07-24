defmodule ExBoxPacker.Sorting.BoxSorter do
  @moduledoc "Behaviour for ordering candidate boxes (analog of BoxPacker's `BoxSorter`)."

  @doc "Return a negative int if `a` sorts before `b`, positive if after, 0 if equal."
  @callback compare(a :: ExBoxPacker.Box.t(), b :: ExBoxPacker.Box.t()) :: integer()
end

defmodule ExBoxPacker.OrientatedItem do
  @moduledoc """
  An item placed in a specific orthogonal orientation (`width` x `length` x `depth`).
  Port of BoxPacker's `OrientatedItem`. `surface_footprint` is the base area
  (`width * length`); `stable?/1` encodes the centre-of-gravity tipping test.
  """

  alias ExBoxPacker.Item

  @enforce_keys [:item, :width, :length, :depth, :surface_footprint]
  defstruct [:item, :width, :length, :depth, :surface_footprint]

  @type t :: %__MODULE__{
          item: Item.t(),
          width: integer(),
          length: integer(),
          depth: integer(),
          surface_footprint: integer()
        }

  @spec new(Item.t(), integer(), integer(), integer()) :: t()
  def new(item, width, length, depth) do
    %__MODULE__{
      item: item,
      width: width,
      length: length,
      depth: depth,
      surface_footprint: width * length
    }
  end

  @doc "True if the orientation has a low enough centre of gravity to be stable."
  @spec stable?(t()) :: boolean()
  def stable?(%__MODULE__{width: w, length: l, depth: d}) do
    denom = if d == 0, do: 1, else: d
    :math.atan(min(l, w) / denom) > 0.261
  end

  @doc "True if `item` has the same set of dimensions (in any order) as this orientation."
  @spec same_dimensions?(t(), Item.t()) :: boolean()
  def same_dimensions?(%__MODULE__{} = o, item) do
    Enum.sort([o.width, o.length, o.depth]) ==
      Enum.sort([Item.width(item), Item.length(item), Item.depth(item)])
  end
end

defimpl String.Chars, for: ExBoxPacker.OrientatedItem do
  def to_string(%{width: w, length: l, depth: d}), do: "#{w}|#{l}|#{d}"
end

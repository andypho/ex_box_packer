defmodule ExBoxPacker.Engine.OrientatedItem do
  @moduledoc false

  alias ExBoxPacker.Engine.{Cache, ItemSpec}
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
    Cache.get_or_compute({:stable, w, l, d}, fn ->
      denom = if d == 0, do: 1, else: d
      :math.atan(min(l, w) / denom) > 0.261
    end)
  end

  @doc "The original user item behind this orientation."
  @spec user_item(t()) :: Item.t()
  def user_item(%__MODULE__{item: item}), do: ItemSpec.user_item(item)

  @doc "True if `spec` has the same set of dimensions (in any order) as this orientation."
  @spec same_dimensions?(t(), ItemSpec.t()) :: boolean()
  def same_dimensions?(%__MODULE__{} = o, %ItemSpec{sorted_dims: dims}) do
    Enum.sort([o.width, o.length, o.depth]) == dims
  end
end

defimpl String.Chars, for: ExBoxPacker.Engine.OrientatedItem do
  def to_string(%{width: w, length: l, depth: d}), do: "#{w}|#{l}|#{d}"
end

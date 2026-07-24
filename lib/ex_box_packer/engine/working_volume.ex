defmodule ExBoxPacker.WorkingVolume do
  @moduledoc false

  @enforce_keys [:width, :length, :depth, :max_weight]
  defstruct [:width, :length, :depth, :max_weight]

  @type t :: %__MODULE__{
          width: integer(),
          length: integer(),
          depth: integer(),
          max_weight: integer()
        }
end

defimpl ExBoxPacker.Box, for: ExBoxPacker.WorkingVolume do
  def reference(%{width: w, length: l, depth: d}), do: "Working Volume #{w}x#{l}x#{d}"
  def outer_width(v), do: v.width
  def outer_length(v), do: v.length
  def outer_depth(v), do: v.depth
  def empty_weight(_v), do: 0
  def inner_width(v), do: v.width
  def inner_length(v), do: v.length
  def inner_depth(v), do: v.depth
  def max_weight(v), do: v.max_weight
end

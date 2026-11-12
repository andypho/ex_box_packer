defmodule ExBoxPacker.Engine.VoidSpace do
  @moduledoc false
  # An empty axis-aligned region inside a box. Port of BoxPacker's `VoidSpace` (4.3.0).

  @enforce_keys [:x, :y, :z, :width, :length, :depth, :volume, :footprint]
  defstruct [:x, :y, :z, :width, :length, :depth, :volume, :footprint]

  @type t :: %__MODULE__{
          x: integer(),
          y: integer(),
          z: integer(),
          width: integer(),
          length: integer(),
          depth: integer(),
          volume: integer(),
          footprint: integer()
        }

  @spec new(integer(), integer(), integer(), integer(), integer(), integer()) :: t()
  def new(x, y, z, width, length, depth) do
    %__MODULE__{
      x: x,
      y: y,
      z: z,
      width: width,
      length: length,
      depth: depth,
      volume: width * length * depth,
      footprint: width * length
    }
  end
end

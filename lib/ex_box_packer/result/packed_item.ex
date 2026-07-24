defmodule ExBoxPacker.Result.PackedItem do
  @moduledoc """
  An item placed inside a box: back-left-bottom corner at `(x, y, z)` with the given
  post-rotation `width`/`length`/`depth`. `volume` is precomputed. Port of BoxPacker's `PackedItem`.
  """

  alias ExBoxPacker.Item

  @enforce_keys [:item, :x, :y, :z, :width, :length, :depth, :volume]
  defstruct [:item, :x, :y, :z, :width, :length, :depth, :volume]

  @type t :: %__MODULE__{
          item: Item.t(),
          x: integer(),
          y: integer(),
          z: integer(),
          width: integer(),
          length: integer(),
          depth: integer(),
          volume: integer()
        }

  @spec new(Item.t(), integer(), integer(), integer(), integer(), integer(), integer()) :: t()
  def new(item, x, y, z, width, length, depth) do
    %__MODULE__{
      item: item,
      x: x,
      y: y,
      z: z,
      width: width,
      length: length,
      depth: depth,
      volume: width * length * depth
    }
  end
end

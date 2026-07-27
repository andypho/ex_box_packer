defmodule ExBoxPacker.Test.THPackTestItem do
  @moduledoc false
  # Port of BoxPacker's tests/Test/THPackTestItem.php.
  #
  # Each academic-benchmark item type carries three per-dimension "allowed vertical"
  # flags (whether that dimension may point upwards, i.e. become the packed depth).
  # The allowed_rotation is derived exactly as PHP does, and the ConstrainedPlacementItem
  # hook enforces the flags for each candidate placement.
  defstruct [
    :description,
    :width,
    :width_allowed_vertical,
    :length,
    :length_allowed_vertical,
    :depth,
    :depth_allowed_vertical,
    quantity: 1
  ]

  @type t :: %__MODULE__{
          description: String.t(),
          width: integer(),
          width_allowed_vertical: boolean(),
          length: integer(),
          length_allowed_vertical: boolean(),
          depth: integer(),
          depth_allowed_vertical: boolean(),
          quantity: pos_integer()
        }

  @doc """
  Replicates PHP `getAllowedRotation()`:

      (!widthAllowedVertical && !lengthAllowedVertical && depthAllowedVertical)
        ? Rotation::KeepFlat : Rotation::BestFit
  """
  @spec allowed_rotation(t()) :: ExBoxPacker.Rotation.t()
  def allowed_rotation(%__MODULE__{
        width_allowed_vertical: false,
        length_allowed_vertical: false,
        depth_allowed_vertical: true
      }),
      do: :keep_flat

  def allowed_rotation(%__MODULE__{}), do: :best_fit
end

defimpl ExBoxPacker.Item, for: ExBoxPacker.Test.THPackTestItem do
  alias ExBoxPacker.Test.THPackTestItem

  def description(item), do: item.description
  def width(item), do: item.width
  def length(item), do: item.length
  def depth(item), do: item.depth
  def weight(_item), do: 0
  def allowed_rotation(item), do: THPackTestItem.allowed_rotation(item)
end

defimpl ExBoxPacker.ConstrainedPlacementItem, for: ExBoxPacker.Test.THPackTestItem do
  # Port of PHP canBePacked(): the placed depth (what points up) must correspond to an
  # original dimension that is flagged as allowed-vertical.
  def can_be_packed?(item, _packed_box, _x, _y, _z, _width, _length, depth) do
    (depth == item.width and item.width_allowed_vertical) or
      (depth == item.length and item.length_allowed_vertical) or
      (depth == item.depth and item.depth_allowed_vertical)
  end
end

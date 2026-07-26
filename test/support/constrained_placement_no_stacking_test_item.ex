defmodule ExBoxPacker.Test.ConstrainedPlacementNoStackingTestItem do
  @moduledoc false
  # Port of BoxPacker's ConstrainedPlacementNoStackingTestItem: forbids placing an item of
  # the same description directly on top of an already-packed one.
  defstruct description: nil,
            width: nil,
            length: nil,
            depth: nil,
            weight: nil,
            allowed_rotation: :best_fit,
            quantity: 1

  @type t :: %__MODULE__{
          description: String.t() | nil,
          width: integer() | nil,
          length: integer() | nil,
          depth: integer() | nil,
          weight: integer() | nil,
          allowed_rotation: ExBoxPacker.Rotation.t(),
          quantity: pos_integer()
        }
end

defimpl ExBoxPacker.Item, for: ExBoxPacker.Test.ConstrainedPlacementNoStackingTestItem do
  def description(item), do: item.description
  def width(item), do: item.width
  def length(item), do: item.length
  def depth(item), do: item.depth
  def weight(item), do: item.weight
  def allowed_rotation(item), do: item.allowed_rotation
end

defimpl ExBoxPacker.ConstrainedPlacementItem,
  for: ExBoxPacker.Test.ConstrainedPlacementNoStackingTestItem do
  alias ExBoxPacker.Item

  def can_be_packed?(
        item,
        packed_box,
        proposed_x,
        proposed_y,
        proposed_z,
        _width,
        _length,
        _depth
      ) do
    packed_box.items.items
    |> Enum.filter(fn packed -> Item.description(packed.item) == item.description end)
    |> Enum.all?(fn packed ->
      not (packed.z + packed.depth == proposed_z and
             proposed_x >= packed.x and proposed_x <= packed.x + packed.width and
             proposed_y >= packed.y and proposed_y <= packed.y + packed.length)
    end)
  end
end

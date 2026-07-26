defmodule ExBoxPacker.Test.ConstrainedPlacementByCountTestItem do
  @moduledoc false
  # Port of BoxPacker's ConstrainedPlacementByCountTestItem: allows at most `limit` items
  # of the same description per box. `limit` is a struct field (the PHP double uses a static).
  defstruct description: nil,
            width: nil,
            length: nil,
            depth: nil,
            weight: nil,
            allowed_rotation: :best_fit,
            limit: 2,
            quantity: 1

  @type t :: %__MODULE__{
          description: String.t() | nil,
          width: integer() | nil,
          length: integer() | nil,
          depth: integer() | nil,
          weight: integer() | nil,
          allowed_rotation: ExBoxPacker.Rotation.t(),
          limit: pos_integer(),
          quantity: pos_integer()
        }
end

defimpl ExBoxPacker.Item, for: ExBoxPacker.Test.ConstrainedPlacementByCountTestItem do
  def description(item), do: item.description
  def width(item), do: item.width
  def length(item), do: item.length
  def depth(item), do: item.depth
  def weight(item), do: item.weight
  def allowed_rotation(item), do: item.allowed_rotation
end

defimpl ExBoxPacker.ConstrainedPlacementItem,
  for: ExBoxPacker.Test.ConstrainedPlacementByCountTestItem do
  alias ExBoxPacker.Item

  def can_be_packed?(item, packed_box, _x, _y, _z, _width, _length, _depth) do
    already_packed =
      Enum.count(packed_box.items.items, fn packed ->
        Item.description(packed.item) == item.description
      end)

    already_packed + 1 <= item.limit
  end
end

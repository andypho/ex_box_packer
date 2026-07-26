defmodule ExBoxPacker.Test.LinkedTestItem do
  @moduledoc false
  # Port of BoxPacker's LinkedTestItem: an item belonging to a named linked group. All items
  # sharing the same group identifier must be packed into the same box.
  defstruct description: nil,
            width: nil,
            length: nil,
            depth: nil,
            weight: nil,
            allowed_rotation: :best_fit,
            linked_item_group: nil

  @type t :: %__MODULE__{
          description: String.t() | nil,
          width: integer() | nil,
          length: integer() | nil,
          depth: integer() | nil,
          weight: integer() | nil,
          allowed_rotation: ExBoxPacker.Rotation.t(),
          linked_item_group: String.t() | nil
        }
end

defimpl ExBoxPacker.Item, for: ExBoxPacker.Test.LinkedTestItem do
  def description(item), do: item.description
  def width(item), do: item.width
  def length(item), do: item.length
  def depth(item), do: item.depth
  def weight(item), do: item.weight
  def allowed_rotation(item), do: item.allowed_rotation
end

defimpl ExBoxPacker.LinkedItem, for: ExBoxPacker.Test.LinkedTestItem do
  def linked_item_group(item), do: item.linked_item_group
end

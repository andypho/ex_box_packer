defmodule ExBoxPacker.SimpleItem do
  @moduledoc """
  A ready-made `ExBoxPacker.Item` implementation for the common case.

  `quantity` is a convenience (default `1`) expanded to N identical units by
  `ExBoxPacker.ItemList.from_items/2`. It is not part of the `Item` protocol.
  """

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

defimpl ExBoxPacker.Item, for: ExBoxPacker.SimpleItem do
  def description(item), do: item.description
  def width(item), do: item.width
  def length(item), do: item.length
  def depth(item), do: item.depth
  def weight(item), do: item.weight
  def allowed_rotation(item), do: item.allowed_rotation
end

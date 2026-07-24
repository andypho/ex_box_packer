defprotocol ExBoxPacker.Item do
  @moduledoc """
  An item to be packed. Elixir analog of BoxPacker's `Item` interface.

  All dimensions are integers in a caller-chosen unit (e.g. mm); weight is an integer
  in a caller-chosen unit (e.g. g). Be consistent across all items and boxes.
  """

  @spec description(t()) :: String.t()
  def description(item)

  @spec width(t()) :: integer()
  def width(item)

  @spec length(t()) :: integer()
  def length(item)

  @spec depth(t()) :: integer()
  def depth(item)

  @spec weight(t()) :: integer()
  def weight(item)

  @spec allowed_rotation(t()) :: ExBoxPacker.Rotation.t()
  def allowed_rotation(item)
end

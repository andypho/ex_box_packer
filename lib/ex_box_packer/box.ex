defprotocol ExBoxPacker.Box do
  @moduledoc """
  A box/container available for packing. Elixir analog of BoxPacker's `Box` interface.

  Outer dimensions/weight are used for shipping; inner dimensions bound the packable
  space. All values are integers in the same units used for items.
  """

  @spec reference(t()) :: String.t()
  def reference(box)

  @spec outer_width(t()) :: integer()
  def outer_width(box)

  @spec outer_length(t()) :: integer()
  def outer_length(box)

  @spec outer_depth(t()) :: integer()
  def outer_depth(box)

  @spec empty_weight(t()) :: integer()
  def empty_weight(box)

  @spec inner_width(t()) :: integer()
  def inner_width(box)

  @spec inner_length(t()) :: integer()
  def inner_length(box)

  @spec inner_depth(t()) :: integer()
  def inner_depth(box)

  @spec max_weight(t()) :: integer()
  def max_weight(box)
end

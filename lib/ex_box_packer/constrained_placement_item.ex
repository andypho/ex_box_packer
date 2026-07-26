defprotocol ExBoxPacker.ConstrainedPlacementItem do
  @moduledoc """
  Optional protocol for items with custom placement rules (e.g. max quantity per box, no
  stacking). `can_be_packed?/8` is consulted for each candidate placement; return false to
  forbid it. Implementing this slows packing. Port of BoxPacker's `ConstrainedPlacementItem`.
  """

  @spec can_be_packed?(
          t(),
          ExBoxPacker.Result.PackedBox.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: boolean()
  def can_be_packed?(item, packed_box, x, y, z, width, length, depth)
end

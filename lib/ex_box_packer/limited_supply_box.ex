defprotocol ExBoxPacker.LimitedSupplyBox do
  @moduledoc """
  Optional protocol for boxes with a finite supply. A box implementing this is only used up
  to `quantity_available/1` times. Boxes that do not implement it are treated as unlimited.
  Port of BoxPacker's `LimitedSupplyBox`.
  """

  @spec quantity_available(t()) :: non_neg_integer()
  def quantity_available(box)
end

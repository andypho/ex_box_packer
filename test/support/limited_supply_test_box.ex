defmodule ExBoxPacker.Test.LimitedSupplyTestBox do
  @moduledoc false
  defstruct [
    :reference,
    :outer_width,
    :outer_length,
    :outer_depth,
    :empty_weight,
    :inner_width,
    :inner_length,
    :inner_depth,
    :max_weight,
    :quantity
  ]
end

defimpl ExBoxPacker.Box, for: ExBoxPacker.Test.LimitedSupplyTestBox do
  def reference(b), do: b.reference
  def outer_width(b), do: b.outer_width
  def outer_length(b), do: b.outer_length
  def outer_depth(b), do: b.outer_depth
  def empty_weight(b), do: b.empty_weight
  def inner_width(b), do: b.inner_width
  def inner_length(b), do: b.inner_length
  def inner_depth(b), do: b.inner_depth
  def max_weight(b), do: b.max_weight
end

defimpl ExBoxPacker.LimitedSupplyBox, for: ExBoxPacker.Test.LimitedSupplyTestBox do
  def quantity_available(b), do: b.quantity
end

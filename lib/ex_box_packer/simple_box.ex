defmodule ExBoxPacker.SimpleBox do
  @moduledoc "A ready-made `ExBoxPacker.Box` implementation for the common case."

  @enforce_keys [
    :reference,
    :outer_width,
    :outer_length,
    :outer_depth,
    :empty_weight,
    :inner_width,
    :inner_length,
    :inner_depth,
    :max_weight
  ]
  defstruct [
    :reference,
    :outer_width,
    :outer_length,
    :outer_depth,
    :empty_weight,
    :inner_width,
    :inner_length,
    :inner_depth,
    :max_weight
  ]

  @type t :: %__MODULE__{
          reference: String.t(),
          outer_width: integer(),
          outer_length: integer(),
          outer_depth: integer(),
          empty_weight: integer(),
          inner_width: integer(),
          inner_length: integer(),
          inner_depth: integer(),
          max_weight: integer()
        }
end

defimpl ExBoxPacker.Box, for: ExBoxPacker.SimpleBox do
  def reference(box), do: box.reference
  def outer_width(box), do: box.outer_width
  def outer_length(box), do: box.outer_length
  def outer_depth(box), do: box.outer_depth
  def empty_weight(box), do: box.empty_weight
  def inner_width(box), do: box.inner_width
  def inner_length(box), do: box.inner_length
  def inner_depth(box), do: box.inner_depth
  def max_weight(box), do: box.max_weight
end

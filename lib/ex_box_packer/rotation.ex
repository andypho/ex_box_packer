defmodule ExBoxPacker.Rotation do
  @moduledoc """
  Allowed rotation modes for an item, mirroring BoxPacker's `Rotation` enum.

    * `:never`     — the item is packed exactly as supplied (1 permutation)
    * `:keep_flat` — the item may rotate in the horizontal plane only (2 permutations)
    * `:best_fit`  — the item may take any of its 6 orthogonal orientations
  """

  @type t :: :never | :keep_flat | :best_fit

  @values [:never, :keep_flat, :best_fit]

  @spec values() :: [t()]
  def values, do: @values

  @spec valid?(term()) :: boolean()
  def valid?(rotation), do: rotation in @values

  @doc "Number of orientation permutations allowed (matches BoxPacker's enum integer values: 1/2/6)."
  @spec permutation_count(t()) :: 1 | 2 | 6
  def permutation_count(:never), do: 1
  def permutation_count(:keep_flat), do: 2
  def permutation_count(:best_fit), do: 6
end

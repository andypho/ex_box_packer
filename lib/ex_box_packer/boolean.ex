defmodule ExBoxPacker.Boolean do
  @moduledoc """
  Boolean utility functions.
  """

  @doc """
  Converts a boolean to an integer (true -> 1, false -> 0).
  """
  @spec to_integer(boolean()) :: 0 | 1
  def to_integer(true), do: 1
  def to_integer(false), do: 0
end

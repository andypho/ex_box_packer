defmodule ExBoxPacker.TimeoutError do
  @moduledoc """
  Raised when packing exceeds the configured timeout. Port of BoxPacker's `TimeoutException`.

  `spent_time` and `timeout` are both in seconds.
  """

  defexception [:message, :spent_time, :timeout]

  @type t :: %__MODULE__{message: String.t(), spent_time: float(), timeout: float()}
end

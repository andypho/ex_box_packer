defmodule ExBoxPacker.Broadcast.Event do
  @moduledoc "A packing event streamed to subscribers: `:started`, `:box_packed`, or `:done`."

  alias ExBoxPacker.Result.PackedBox

  @enforce_keys [:type]
  defstruct [:type, :box, :summary]

  @type t :: %__MODULE__{
          type: :started | :box_packed | :done,
          box: PackedBox.t() | nil,
          summary: map() | nil
        }
end

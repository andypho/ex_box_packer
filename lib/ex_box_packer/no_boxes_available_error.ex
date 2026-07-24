defmodule ExBoxPacker.NoBoxesAvailableError do
  @moduledoc """
  Raised (by `pack!/3`) or returned in `{:error, _}` (by `pack/3`) when an item cannot be
  packed into any available box. `affected_items` holds the items that could not be packed.
  Port of BoxPacker's `NoBoxesAvailableException`.
  """

  defexception [:message, :affected_items]

  @type t :: %__MODULE__{message: String.t(), affected_items: [ExBoxPacker.Item.t()]}

  @impl true
  def exception(items) when is_list(items) and items != [] do
    top = hd(items)

    %__MODULE__{
      message: "No boxes could be found for item '#{ExBoxPacker.Item.description(top)}'",
      affected_items: items
    }
  end
end

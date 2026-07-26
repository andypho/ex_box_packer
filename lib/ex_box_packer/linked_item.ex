defprotocol ExBoxPacker.LinkedItem do
  @moduledoc """
  Optional protocol marking items that belong to a named group which must all ship together
  in the same box (never split across boxes). Port of BoxPacker's `LinkedItem`.
  """

  @spec linked_item_group(t()) :: String.t()
  def linked_item_group(item)
end

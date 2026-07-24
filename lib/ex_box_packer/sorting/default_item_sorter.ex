defmodule ExBoxPacker.Sorting.DefaultItemSorter do
  @moduledoc "Default item ordering: volume desc, then weight desc, then description asc."
  @behaviour ExBoxPacker.Sorting.ItemSorter

  import ExBoxPacker.Sorting.ItemSorter, only: [cmp: 2]
  alias ExBoxPacker.Item

  @impl true
  def compare(a, b) do
    vol_a = Item.width(a) * Item.length(a) * Item.depth(a)
    vol_b = Item.width(b) * Item.length(b) * Item.depth(b)

    case cmp(vol_b, vol_a) do
      0 ->
        case cmp(Item.weight(b), Item.weight(a)) do
          0 -> cmp(Item.description(a), Item.description(b))
          weight_decider -> weight_decider
        end

      volume_decider ->
        volume_decider
    end
  end
end

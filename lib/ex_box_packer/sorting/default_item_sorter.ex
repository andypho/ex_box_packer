defmodule ExBoxPacker.Sorting.DefaultItemSorter do
  @moduledoc """
  Default item ordering: linked group asc (ungrouped items first), then volume desc, then
  weight desc, then description asc.

  Keeping each `ExBoxPacker.LinkedItem` group contiguous gives its members the best chance of
  landing in the same box (BoxPacker #664).
  """
  @behaviour ExBoxPacker.Sorting.ItemSorter

  import ExBoxPacker.Sorting.ItemSorter, only: [cmp: 2]
  alias ExBoxPacker.{Item, LinkedItem}

  @impl true
  def compare(a, b) do
    case {linked_item_group(a), linked_item_group(b)} do
      {same, same} -> compare_by_size(a, b)
      # PHP `null <=> "group"` coerces null to "", so ungrouped items sort before grouped ones.
      {group_a, group_b} -> cmp(group_a || "", group_b || "")
    end
  end

  defp compare_by_size(a, b) do
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

  # nil for items that don't implement the optional LinkedItem protocol. Both calls are
  # routed through `apply/3` (as in WeightRedistributor): no implementation exists in lib, so
  # the type checker would otherwise infer `impl_for/1` is always nil and flag the branch.
  # credo:disable-for-lines:3 Credo.Check.Refactor.Apply
  defp linked_item_group(item) do
    if apply(LinkedItem, :impl_for, [item]), do: apply(LinkedItem, :linked_item_group, [item])
  end
end

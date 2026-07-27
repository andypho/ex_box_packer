defmodule ExBoxPacker.Engine.WeightRedistributor do
  @moduledoc false

  # Faithful functional port of BoxPacker's WeightRedistributor. For a pair of boxes it
  # greedily moves ALL beneficial items from the heavier box to the lighter one (in original
  # item order) whenever a move reduces the 2-box weight variance and the item still fits in a
  # single box. LinkedItem members are never moved. Box-quantity tracking is deferred (M5).

  alias ExBoxPacker.{Item, Packer}
  alias ExBoxPacker.Result.{PackedBox, PackedBoxList, PackedItemList}

  @doc "Rebalance weight across `packed` (a PackedBoxList). `boxes` is the full catalog; `sorter` orders the result."
  @spec redistribute(PackedBoxList.t(), [ExBoxPacker.Box.t()], module()) :: PackedBoxList.t()
  def redistribute(%PackedBoxList{} = packed, boxes, sorter) do
    target = PackedBoxList.mean_item_weight(packed)

    packed
    |> PackedBoxList.to_list()
    |> Enum.sort(&(PackedBox.weight(&1) >= PackedBox.weight(&2)))
    |> loop(target, boxes, sorter)
    |> PackedBoxList.from_list(sorter)
  end

  defp loop(box_list, target, boxes, sorter) do
    case find_and_equalise(box_list, target, boxes, sorter) do
      {:ok, new_list} -> loop(new_list, target, boxes, sorter)
      :none -> box_list
    end
  end

  # Find the first pair (a < b) with differing weights where a beneficial move succeeds.
  defp find_and_equalise(box_list, target, boxes, sorter) do
    indexed = Enum.with_index(box_list)

    Enum.find_value(indexed, :none, fn {box_a, a} ->
      Enum.find_value(indexed, &try_pair(&1, box_a, a, box_list, target, boxes, sorter))
    end)
  end

  defp try_pair({box_b, b}, box_a, a, box_list, target, boxes, sorter) do
    if b > a and PackedBox.weight(box_a) != PackedBox.weight(box_b) do
      apply_move(equalise(box_a, box_b, target, boxes, sorter), a, b, box_list)
    end
  end

  defp apply_move(:none, _a, _b, _box_list), do: nil

  defp apply_move({:ok, new_a, new_b}, a, b, box_list) do
    new_list =
      box_list
      |> List.replace_at(a, new_a)
      |> List.replace_at(b, new_b)
      |> Enum.reject(&is_nil/1)

    {:ok, new_list}
  end

  # Greedily move ALL beneficial items from the heavier of the two boxes to the lighter one in
  # a single call (port of PHP `equaliseWeight`'s `foreach ($overWeightBoxItems ...)` loop).
  # Returns {:ok, new_a, new_b} (either may be nil if that box is eliminated) or :none.
  defp equalise(box_a, box_b, target, boxes, sorter) do
    {over, under, over_is_a?} =
      if PackedBox.weight(box_a) > PackedBox.weight(box_b),
        do: {box_a, box_b, true},
        else: {box_b, box_a, false}

    over_items = PackedItemList.as_items(over.items)
    under_items = PackedItemList.as_items(under.items)

    # Iterate the ORIGINAL over_items in order, threading the mutating state.
    result =
      Enum.reduce(over_items, {over_items, under_items, over, under, false}, fn item, state ->
        try_move(item, state, target, boxes, sorter)
      end)

    case result do
      # A move eliminated the over box: over = nil, under = new_lighter.
      {:eliminated, new_lighter} ->
        put_back(over_is_a?, nil, new_lighter)

      {_over_remaining, _under_current, _over_box, _under_box, false} ->
        :none

      {_over_remaining, _under_current, over_box, under_box, true} ->
        put_back(over_is_a?, over_box, under_box)
    end
  end

  # Once the over box has been eliminated, later iterations are no-ops.
  defp try_move(_item, {:eliminated, _} = done, _target, _boxes, _sorter), do: done

  defp try_move(item, state, target, boxes, sorter) do
    {over_remaining, under_current, _over_box, _under_box, _any_moved?} = state

    with false <- linked_item?(item),
         true <- would_help?(over_remaining, item, under_current, target),
         {lighter, []} <- repack(boxes, under_current ++ [item], sorter),
         true <- PackedBoxList.count(lighter) == 1 do
      new_lighter = PackedBoxList.top(lighter)
      new_under_current = under_current ++ [item]

      if List.delete(over_remaining, item) == [] do
        # Over box held exactly this one item — the repack eliminated it.
        {:eliminated, new_lighter}
      else
        new_over_remaining = List.delete(over_remaining, item)
        finish_move(new_over_remaining, new_under_current, new_lighter, state, boxes, sorter)
      end
    else
      # LinkedItem, not helpful, or would not fit in a single box — skip this item.
      _ -> state
    end
  end

  # Repack the over box's remaining items; if they don't fit in exactly one box, revert (be
  # defensive — PHP asserts n-1 always fits). Otherwise commit the move and continue.
  defp finish_move(over_remaining, under_current, new_lighter, prev_state, boxes, sorter) do
    with {heavier, []} <- repack(boxes, over_remaining, sorter),
         true <- PackedBoxList.count(heavier) == 1 do
      {over_remaining, under_current, PackedBoxList.top(heavier), new_lighter, true}
    else
      _ -> prev_state
    end
  end

  # Map the new over/under boxes back to the a/b positions.
  defp put_back(true = _over_is_a?, new_over, new_under), do: {:ok, new_over, new_under}
  defp put_back(false, new_over, new_under), do: {:ok, new_under, new_over}

  # Does `item` implement the optional LinkedItem protocol? Routed through `apply/3` for the
  # same reason as Packer.initial_quantities (avoid a spurious unreachable-branch warning).
  # credo:disable-for-next-line Credo.Check.Refactor.Apply
  defp linked_item?(item), do: apply(ExBoxPacker.LinkedItem, :impl_for, [item]) != nil

  defp repack(boxes, items, sorter) do
    Packer.pack_all_possible(boxes, items, packed_box_sorter: sorter, enforce_single_box?: true)
  end

  # Would moving `item` from over to under reduce the 2-box weight variance without
  # overshooting the target? (Port of wouldRepackActuallyHelp.)
  defp would_help?(over_items, item, under_items, target) do
    over_weight = total_weight(over_items)
    under_weight = total_weight(under_items)
    item_weight = Item.weight(item)

    if item_weight + under_weight > target do
      false
    else
      old_variance = variance(over_weight, under_weight)
      new_variance = variance(over_weight - item_weight, under_weight + item_weight)
      new_variance < old_variance
    end
  end

  defp total_weight(items), do: Enum.reduce(items, 0, fn i, acc -> acc + Item.weight(i) end)

  # For a 2-box population the squared deviation from the mean is identical for both boxes,
  # so one term suffices (matches PHP's calculateVariance).
  defp variance(a_weight, b_weight) do
    mean = (a_weight + b_weight) / 2
    :math.pow(a_weight - mean, 2)
  end
end

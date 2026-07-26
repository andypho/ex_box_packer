defmodule ExBoxPacker.Engine.WeightRedistributor do
  @moduledoc false

  # Faithful functional port of BoxPacker's WeightRedistributor. Moves items from heavier
  # boxes to lighter ones when it reduces the 2-box weight variance and the item still fits
  # in a single box. Box-quantity tracking and linked-item handling are deferred (M5).

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

  # Try to move ONE beneficial item from the heavier of the two boxes to the lighter one.
  # Returns {:ok, new_a, new_b} (either may be nil if that box is eliminated) or :none.
  defp equalise(box_a, box_b, target, boxes, sorter) do
    {over, under, over_is_a?} =
      if PackedBox.weight(box_a) > PackedBox.weight(box_b),
        do: {box_a, box_b, true},
        else: {box_b, box_a, false}

    over_items = PackedItemList.as_items(over.items)
    under_items = PackedItemList.as_items(under.items)

    move =
      Enum.find_value(over_items, fn item ->
        with true <- would_help?(over_items, item, under_items, target),
             {lighter, []} <- repack(boxes, under_items ++ [item], sorter),
             true <- PackedBoxList.count(lighter) == 1 do
          {item, PackedBoxList.top(lighter)}
        else
          _ -> nil
        end
      end)

    case move do
      nil ->
        :none

      {item, new_lighter} ->
        apply_over(List.delete(over_items, item), new_lighter, over_is_a?, boxes, sorter)
    end
  end

  # Rebuild the over box from its remaining items (or eliminate it when empty).
  defp apply_over([], new_lighter, over_is_a?, _boxes, _sorter) do
    # over box eliminated
    put_back(over_is_a?, nil, new_lighter)
  end

  defp apply_over(remaining_over, new_lighter, over_is_a?, boxes, sorter) do
    with {heavier, []} <- repack(boxes, remaining_over, sorter),
         true <- PackedBoxList.count(heavier) == 1 do
      put_back(over_is_a?, PackedBoxList.top(heavier), new_lighter)
    else
      _ -> :none
    end
  end

  # Map the new over/under boxes back to the a/b positions.
  defp put_back(true = _over_is_a?, new_over, new_under), do: {:ok, new_over, new_under}
  defp put_back(false, new_over, new_under), do: {:ok, new_under, new_over}

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

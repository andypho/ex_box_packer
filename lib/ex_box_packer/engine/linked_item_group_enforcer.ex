defmodule ExBoxPacker.Engine.LinkedItemGroupEnforcer do
  @moduledoc false

  # Enforces the constraint that linked item groups must not be split across boxes.
  # If a packed box contains only some members of a linked group, those members are
  # removed and the box is repacked without them so the freed space can be used by
  # other eligible items.
  #
  # The enforcement loop is iterative and accumulates excluded group IDs so that
  # items drawn in from the remaining item list on one pass cannot reintroduce a group
  # that was already excluded on an earlier pass. The loop terminates because the set of
  # excluded groups can only grow, and the eligible item list can only shrink.
  #
  # Faithful port of BoxPacker's `LinkedItemGroupEnforcer`.

  alias ExBoxPacker.Engine.VolumePacker
  alias ExBoxPacker.LinkedItem
  alias ExBoxPacker.Result.{PackedBox, PackedItemList}

  @doc """
  Enforce the linked-group constraint on `candidate` (a `PackedBox`), given the current
  `remaining_items` list. Returns a possibly-repacked `PackedBox` (always using the
  original candidate's box). `strict?` maps to VolumePacker's `strict_ordering?`.
  """
  @spec enforce_constraint(PackedBox.t(), [ExBoxPacker.Item.t()], boolean()) :: PackedBox.t()
  def enforce_constraint(%PackedBox{} = candidate, remaining_items, strict?) do
    if has_linked_items?(remaining_items) do
      loop(candidate, candidate, remaining_items, %{}, strict?)
    else
      candidate
    end
  end

  # while there are linked groups that are incomplete, repack without that linked group
  # so that we fill up the remaining space, while eliminating linked group items that do
  # not fully fit in it. When there are no incomplete linked groups remaining we can
  # return the packed box.
  defp loop(candidate, current, remaining_items, excluded, strict?) do
    incomplete = find_incomplete_linked_groups(current, remaining_items, excluded)

    if map_size(incomplete) == 0 do
      current
    else
      excluded = Map.merge(excluded, incomplete)
      eligible = build_eligible_items(remaining_items, excluded)
      repacked = repack_box(candidate, eligible, strict?)
      loop(candidate, repacked, remaining_items, excluded, strict?)
    end
  end

  # Returns the set of linked group IDs that are not all included in `current`
  # and are not yet in `already_excluded`.
  defp find_incomplete_linked_groups(current, remaining_items, already_excluded) do
    total_counts = linked_group_counts(remaining_items)

    current.items
    |> packed_linked_group_counts()
    |> Enum.reduce(%{}, fn {group_id, packed_count}, acc ->
      if not Map.has_key?(already_excluded, group_id) and
           packed_count < Map.get(total_counts, group_id, 0) do
        Map.put(acc, group_id, true)
      else
        acc
      end
    end)
  end

  # Builds a list of items eligible for repacking: `remaining_items` with all members of
  # `excluded_groups` removed.
  defp build_eligible_items(remaining_items, excluded_groups) do
    Enum.reject(remaining_items, fn item ->
      linked?(item) and Map.has_key?(excluded_groups, linked_item_group(item))
    end)
  end

  # Repacks `candidate`'s box using only `eligible_items`.
  defp repack_box(%PackedBox{box: box}, [], _strict?),
    do: PackedBox.new(box, PackedItemList.new())

  defp repack_box(%PackedBox{box: box}, eligible_items, strict?) do
    VolumePacker.pack(box, eligible_items, strict_ordering?: strict?)
  end

  defp has_linked_items?(items), do: Enum.any?(items, &linked?/1)

  defp linked?(item), do: LinkedItem.impl_for(item) != nil

  # Routed through `apply/3` so the compile-time type checker does not flag this optional
  # extension protocol (only user/test code implements it). Every call is guarded by
  # `linked?/1`; runtime behaviour is identical to a direct `LinkedItem.linked_item_group/1`.
  # credo:disable-for-next-line Credo.Check.Refactor.Apply
  defp linked_item_group(item), do: apply(LinkedItem, :linked_item_group, [item])

  # Map of group => count of items in `items` that implement LinkedItem with that group.
  defp linked_group_counts(items) do
    Enum.reduce(items, %{}, fn item, acc ->
      if linked?(item) do
        Map.update(acc, linked_item_group(item), 1, &(&1 + 1))
      else
        acc
      end
    end)
  end

  # Map of group => count of packed items whose underlying item is a LinkedItem of that group.
  defp packed_linked_group_counts(%PackedItemList{items: items}) do
    Enum.reduce(items, %{}, fn packed_item, acc ->
      item = packed_item.item

      if linked?(item) do
        Map.update(acc, linked_item_group(item), 1, &(&1 + 1))
      else
        acc
      end
    end)
  end
end

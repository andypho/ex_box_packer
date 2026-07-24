defmodule ExBoxPacker.OrientatedItemSorter do
  @moduledoc """
  Orders candidate orientations best-first. Port of BoxPacker's `OrientatedItemSorter`.
  Priority: exact fit in width, then length, then depth; then a look-ahead tiebreaker
  (prefer leaving room for the next items); then smallest `min(width_left, length_left)`
  gap; then smallest surface footprint.

  Context is a map:

      %{
        box: Box.t(),
        width_left: integer(), length_left: integer(), depth_left: integer(),
        next_items: [Item.t()],   # remaining items after the current one (extract order)
        row_length: integer(),
        single_pass?: boolean()
      }
  """

  import ExBoxPacker.ItemSorter, only: [cmp: 2]
  alias ExBoxPacker.{OrientatedItem, OrientatedItemFactory}

  @spec compare(OrientatedItem.t(), OrientatedItem.t(), map()) :: -1 | 0 | 1
  def compare(%OrientatedItem{} = a, %OrientatedItem{} = b, ctx) do
    %{width_left: wl, length_left: ll, depth_left: dl} = ctx

    with 0 <- exact_fit_decider(wl - a.width, wl - b.width),
         0 <- exact_fit_decider(ll - a.length, ll - b.length),
         0 <- exact_fit_decider(dl - a.depth, dl - b.depth),
         0 <- look_ahead_decider(a, b, wl - a.width, wl - b.width, ctx) do
      a_min_gap = min(wl - a.width, ll - a.length)
      b_min_gap = min(wl - b.width, ll - b.length)

      case cmp(a_min_gap, b_min_gap) do
        0 -> cmp(a.surface_footprint, b.surface_footprint)
        gap_decider -> gap_decider
      end
    end
  end

  @spec sort([OrientatedItem.t()], map()) :: [OrientatedItem.t()]
  def sort(orientations, ctx), do: Enum.sort(orientations, &(compare(&1, &2, ctx) <= 0))

  # Prefer an orientation that still leaves room for the next item. Full behaviour added
  # in Milestone 2b Task 5; until then this compares only the trivial "next item fits at
  # all" case using the (already available) OrientatedItemFactory, then falls through.
  defp look_ahead_decider(_a, _b, _a_width_left, _b_width_left, %{next_items: []}), do: 0

  defp look_ahead_decider(a, b, a_width_left, b_width_left, ctx) do
    [next | _] = ctx.next_items
    space_a = {a_width_left, ctx.length_left, ctx.depth_left}
    space_b = {b_width_left, ctx.length_left, ctx.depth_left}
    fits_a = OrientatedItemFactory.possible_orientations(next, a, space_a) != []
    fits_b = OrientatedItemFactory.possible_orientations(next, b, space_b) != []

    cond do
      fits_a and not fits_b -> -1
      fits_b and not fits_a -> 1
      # deeper partial look-ahead (packing simulation) is added in Task 5
      true -> 0
    end
  end

  defp exact_fit_decider(a_left, b_left) do
    cond do
      a_left == 0 and b_left > 0 -> -1
      a_left > 0 and b_left == 0 -> 1
      true -> 0
    end
  end
end

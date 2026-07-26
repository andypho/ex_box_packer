defmodule ExBoxPacker.Engine.OrientatedItemSorter do
  @moduledoc false

  import ExBoxPacker.Sorting.ItemSorter, only: [cmp: 2]
  alias ExBoxPacker.Engine.{OrientatedItem, OrientatedItemFactory, VolumePacker, WorkingVolume}

  # Look-ahead simulation caps the number of following items considered, matching
  # BoxPacker's `topN(8)` to keep the recursive partial pack bounded.
  @lookahead_item_cap 8
  @lookahead_max_weight 1_000_000_000

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

  # Prefer an orientation that still leaves room for the next item(s). Cheap check first:
  # does the next item fit at all after `a` vs `b`. When that ties, run the partial packing
  # simulation (`additional_packed/2`) and prefer the orientation that packs more.
  defp look_ahead_decider(_a, _b, _a_width_left, _b_width_left, %{next_items: []}), do: 0

  defp look_ahead_decider(a, b, a_width_left, b_width_left, ctx) do
    [next | _] = ctx.next_items
    space_a = {a_width_left, ctx.length_left, ctx.depth_left}
    space_b = {b_width_left, ctx.length_left, ctx.depth_left}
    # Pass the current placement context so the next-item fit respects any placement
    # constraints, matching OrientatedItemSorter::lookAheadDecider (same x/y/z/packed).
    placement = %{
      box: ctx.box,
      x: ctx.x,
      y: ctx.y,
      z: ctx.z,
      packed: ctx.packed,
      box_rotated?: ctx.box_rotated?
    }

    fits_a = OrientatedItemFactory.possible_orientations(next, a, space_a, placement) != []
    fits_b = OrientatedItemFactory.possible_orientations(next, b, space_b, placement) != []

    cond do
      fits_a and not fits_b -> -1
      fits_b and not fits_a -> 1
      true -> cmp(additional_packed(b, ctx), additional_packed(a, ctx))
    end
  end

  # BoxPacker's `calculateAdditionalItemsPackedWithThisOrientation`: single-pass pack of the
  # next (<= 8) items into (a) the remaining current-row width and (b) the remaining rows,
  # counting how many fit. A higher count is better. Returns 0 in single-pass mode so the
  # recursive `VolumePacker.pack(..., single_pass?: true)` cannot re-enter this simulation
  # (guarantees termination).
  defp additional_packed(_prev, %{single_pass?: true}), do: 0

  defp additional_packed(prev_orientation, ctx) do
    current_row_length = max(prev_orientation.length, ctx.row_length)
    items_to_pack = Enum.take(ctx.next_items, @lookahead_item_cap)

    row_box = %WorkingVolume{
      width: ctx.width_left - prev_orientation.width,
      length: current_row_length,
      depth: ctx.depth_left,
      max_weight: @lookahead_max_weight
    }

    row_packed = VolumePacker.pack(row_box, items_to_pack, single_pass?: true)
    remaining = subtract_packed(items_to_pack, row_packed)

    rows_box = %WorkingVolume{
      width: ctx.width_left,
      length: ctx.length_left - current_row_length,
      depth: ctx.depth_left,
      max_weight: @lookahead_max_weight
    }

    rows_packed = VolumePacker.pack(rows_box, remaining, single_pass?: true)
    remaining2 = subtract_packed(remaining, rows_packed)

    # Matches PHP `nextItems.count() - itemsToPack.count()`: items beyond the cap count as
    # packed too. This offset is identical for both compared orientations, so it does not
    # affect the tiebreak, but we mirror the source exactly.
    length(ctx.next_items) - length(remaining2)
  end

  defp subtract_packed(items, %{items: %{items: packed}}) do
    packed
    |> Enum.map(& &1.item)
    |> Enum.reduce(items, fn p, acc -> List.delete(acc, p) end)
  end

  defp exact_fit_decider(a_left, b_left) do
    cond do
      a_left == 0 and b_left > 0 -> -1
      a_left > 0 and b_left == 0 -> 1
      true -> 0
    end
  end
end

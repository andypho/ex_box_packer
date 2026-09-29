defmodule ExBoxPacker.Engine.OrientatedItemSorter do
  @moduledoc false

  import ExBoxPacker.Sorting.ItemSorter, only: [cmp: 2]

  alias ExBoxPacker.Boolean

  alias ExBoxPacker.Engine.{
    Cache,
    OrientatedItem,
    OrientatedItemFactory,
    VolumePacker,
    WorkingVolume
  }

  # Look-ahead simulation caps the number of following items considered, matching
  # BoxPacker's `topN(7)` to keep the recursive partial pack bounded.
  @lookahead_item_cap 7
  @lookahead_max_weight 1_000_000_000

  # Max (smallest / largest) edge ratio for an item to be treated as slab-like: at or below
  # this, BestFit scoring prefers the thin edge as depth (KeepFlat-style).
  @slab_aspect_ratio 0.3

  # The same-size tessellation decider only applies while at least this many same-size
  # items (including the current one) are still to place.
  @min_same_size_items 2

  @spec compare(OrientatedItem.t(), OrientatedItem.t(), map()) :: -1 | 0 | 1
  def compare(%OrientatedItem{} = a, %OrientatedItem{} = b, ctx) do
    %{width_left: wl, length_left: ll, depth_left: dl} = ctx

    with 0 <- exact_fit_decider(wl - a.width, wl - b.width),
         0 <- exact_fit_decider(ll - a.length, ll - b.length),
         0 <- exact_fit_decider(dl - a.depth, dl - b.depth),
         0 <- same_size_items_decider(a, b, ctx),
         0 <- look_ahead_decider(a, b, wl - a.width, wl - b.width, ctx),
         0 <- slab_decider(a, b) do
      a_min_gap = min(wl - a.width, ll - a.length)
      b_min_gap = min(wl - b.width, ll - b.length)

      case cmp(a_min_gap, b_min_gap) do
        0 -> cmp(a.surface_footprint, b.surface_footprint)
        gap_decider -> gap_decider
      end
    end
  end

  @spec sort([OrientatedItem.t()], map()) :: [OrientatedItem.t()]
  def sort([], _ctx), do: []

  def sort([first | _] = orientations, ctx) do
    # Every orientation belongs to the same item, so the same-size check is computed once per
    # sort (BoxPacker caches it per sorter instance).
    ctx = Map.put(ctx, :same_size_count, same_size_count(first.item, ctx.next_items))
    Enum.sort(orientations, &(compare(&1, &2, ctx) <= 0))
  end

  # When every remaining item is the same size as this one, prefer the orientation that fits
  # more of them into the free space on a regular grid (simple arithmetic, not a pack).
  defp same_size_items_decider(a, b, ctx) do
    case Map.get_lazy(ctx, :same_size_count, fn -> same_size_count(a.item, ctx.next_items) end) do
      nil ->
        0

      remaining ->
        fit_a = how_many_fit(a, ctx)
        fit_b = how_many_fit(b, ctx)

        case cmp(covers(fit_b, remaining), covers(fit_a, remaining)) do
          0 -> cmp(fit_b, fit_a)
          covers_decider -> covers_decider
        end
    end
  end

  # Number of same-size items still to place (including the current one), or nil when the
  # decider does not apply (a differently-sized item remains, or too few are left).
  defp same_size_count(item, next_items) do
    remaining = length(next_items) + 1

    if remaining >= @min_same_size_items and
         Enum.all?(next_items, &(&1.sorted_dims == item.sorted_dims)),
       do: remaining
  end

  defp covers(fit, remaining) when fit >= remaining, do: 1
  defp covers(_fit, _remaining), do: 0

  defp how_many_fit(%OrientatedItem{width: w, length: l, depth: d}, _ctx)
       when w <= 0 or l <= 0 or d <= 0,
       do: 0

  defp how_many_fit(%OrientatedItem{width: w, length: l, depth: d}, ctx),
    do: div(ctx.width_left, w) * div(ctx.length_left, l) * div(ctx.depth_left, d)

  # For slab-like BestFit items (one edge much shorter than the longest), prefer the
  # orientation with the thin edge as depth.
  defp slab_decider(
         %OrientatedItem{item: %{rotation: :best_fit, sorted_dims: [thin, _, longest]}} = a,
         b
       )
       when longest != 0 and thin / longest <= @slab_aspect_ratio do
    cmp(Boolean.to_integer(b.depth == thin), Boolean.to_integer(a.depth == thin))
  end

  defp slab_decider(_a, _b), do: 0

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
  # next (<= 7) items into (a) the remaining current-row width and (b) the remaining rows,
  # counting how many fit. A higher count is better. Returns 0 in single-pass mode so the
  # recursive `VolumePacker.pack(..., single_pass?: true)` cannot re-enter this simulation
  # (guarantees termination).
  defp additional_packed(_prev, %{single_pass?: true}), do: 0

  defp additional_packed(prev_orientation, ctx) do
    current_row_length = max(prev_orientation.length, ctx.row_length)

    item_sig =
      ctx.next_items
      |> Enum.take(@lookahead_item_cap)
      |> Enum.map(&{&1.width, &1.length, &1.depth, &1.weight, &1.rotation})

    # The result is `length(next_items) - length(remaining2)`; `remaining2` depends only on the
    # first `@lookahead_item_cap` items (captured by `item_sig`), but the offset uses the FULL
    # tail length, so include it in the key to stay byte-for-byte identical to the uncached path.
    key =
      {:lookahead, ctx.width_left, ctx.length_left, prev_orientation.width,
       prev_orientation.length, current_row_length, ctx.depth_left, length(ctx.next_items),
       item_sig}

    Cache.get_or_compute(key, fn ->
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
    end)
  end

  defp subtract_packed(items, %{items: %{items: packed}}) do
    packed
    |> Enum.map(& &1.item)
    |> Enum.reduce(items, fn p, acc -> delete_first_by_item(acc, p) end)
  end

  # `items` holds ItemSpecs; `user_item` came from a PackedItem, which holds the raw user
  # item. Match on the spec's wrapped item so the identity subtraction still lines up.
  defp delete_first_by_item(list, user_item), do: do_delete_by_item(list, user_item, [])

  defp do_delete_by_item([%{item: user_item} | t], user_item, acc), do: Enum.reverse(acc) ++ t
  defp do_delete_by_item([h | t], user_item, acc), do: do_delete_by_item(t, user_item, [h | acc])
  defp do_delete_by_item([], _user_item, acc), do: Enum.reverse(acc)

  defp exact_fit_decider(a_left, b_left) do
    cond do
      a_left == 0 and b_left > 0 -> -1
      a_left > 0 and b_left == 0 -> 1
      true -> 0
    end
  end
end

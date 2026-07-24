defmodule ExBoxPacker.OrientatedItemFactory do
  @moduledoc """
  Generates and selects item orientations. Port of BoxPacker's `OrientatedItemFactory`
  (stateless here). The look-ahead tiebreaker and `ConstrainedPlacementItem` filtering
  from the original are deferred to later milestones.
  """

  alias ExBoxPacker.{Box, Item, OrientatedItem, OrientatedItemSorter}

  @type dims :: {integer(), integer(), integer()}

  @doc """
  All orthogonal orientations (as `{w, l, d}` tuples) allowed for `item`, deduped by
  dimension signature preserving first-occurrence order. If `prev_item` shares the same
  set of dimensions, its exact orientation is reused (a 1-element list).
  """
  @spec generate_permutations(Item.t(), OrientatedItem.t() | nil) :: [dims()]
  def generate_permutations(item, prev_item) do
    if prev_item && OrientatedItem.same_dimensions?(prev_item, item) do
      [{prev_item.width, prev_item.length, prev_item.depth}]
    else
      w = Item.width(item)
      l = Item.length(item)
      d = Item.depth(item)
      rotation = Item.allowed_rotation(item)

      base = [{w, l, d}]
      base = if rotation != :never, do: base ++ [{l, w, d}], else: base

      all =
        case rotation do
          :best_fit -> base ++ [{w, d, l}, {l, d, w}, {d, w, l}, {d, l, w}]
          _ -> base
        end

      Enum.uniq(all)
    end
  end

  @doc "Orientations from `generate_permutations/2` that fit within `{width, length, depth}` space."
  @spec possible_orientations(Item.t(), OrientatedItem.t() | nil, dims()) :: [OrientatedItem.t()]
  def possible_orientations(item, prev_item, {wl, ll, dl}) do
    item
    |> generate_permutations(prev_item)
    |> Enum.filter(fn {w, l, d} -> w <= wl and l <= ll and d <= dl end)
    |> Enum.map(fn {w, l, d} -> OrientatedItem.new(item, w, l, d) end)
  end

  @doc """
  Filter possible orientations by stability: prefer stable orientations (low centre of
  gravity, or filling the full box depth). Fall back to unstable ones only if the item
  has no stable orientation even in an empty box.
  """
  @spec usable_orientations(Box.t(), Item.t(), [OrientatedItem.t()]) :: [OrientatedItem.t()]
  def usable_orientations(box, item, possible) do
    inner_depth = Box.inner_depth(box)

    {stable, unstable} =
      Enum.split_with(possible, fn o -> OrientatedItem.stable?(o) or o.depth == inner_depth end)

    cond do
      stable != [] -> stable
      unstable != [] and not has_stable_orientations_in_empty_box?(box, item) -> unstable
      true -> []
    end
  end

  @doc "True if `item` has at least one stable orientation when placed in an empty `box`."
  @spec has_stable_orientations_in_empty_box?(Box.t(), Item.t()) :: boolean()
  def has_stable_orientations_in_empty_box?(box, item) do
    item
    |> possible_orientations(
      nil,
      {Box.inner_width(box), Box.inner_length(box), Box.inner_depth(box)}
    )
    |> Enum.any?(&OrientatedItem.stable?/1)
  end

  @doc """
  The best orientation for `item` in the given remaining space, or `nil` if none fit.
  When `consider_stability?` is true, unstable orientations are filtered per
  `usable_orientations/3`. Selection uses `OrientatedItemSorter`.
  """
  @spec best_orientation(Box.t(), Item.t(), OrientatedItem.t() | nil, dims(), boolean()) ::
          OrientatedItem.t() | nil
  def best_orientation(box, item, prev_item, {wl, ll, dl} = space, consider_stability?) do
    possible = possible_orientations(item, prev_item, space)
    usable = if consider_stability?, do: usable_orientations(box, item, possible), else: possible

    case usable do
      [] ->
        nil

      orientations ->
        ctx = %{width_left: wl, length_left: ll, depth_left: dl}

        orientations
        |> OrientatedItemSorter.sort(ctx)
        |> hd()
    end
  end
end

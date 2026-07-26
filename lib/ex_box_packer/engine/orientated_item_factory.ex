defmodule ExBoxPacker.Engine.OrientatedItemFactory do
  @moduledoc false

  alias ExBoxPacker.{Box, ConstrainedPlacementItem, Item}
  alias ExBoxPacker.Engine.{OrientatedItem, OrientatedItemSorter, WorkingVolume}
  alias ExBoxPacker.Result.{PackedBox, PackedItem, PackedItemList}

  @type dims :: {integer(), integer(), integer()}

  @typedoc """
  Placement context threaded through the orientation API so per-placement constraints
  (`ExBoxPacker.ConstrainedPlacementItem`) can be evaluated. `box` is the box being packed,
  `x`/`y`/`z` the candidate position, `packed` the already-packed list, `box_rotated?` whether
  the box footprint is being tried rotated. An empty map (or missing keys) means "no
  constraint context" and skips the filter — used by callers that only need pure fit checks.
  """
  @type ctx :: %{
          optional(:box) => Box.t(),
          optional(:x) => integer(),
          optional(:y) => integer(),
          optional(:z) => integer(),
          optional(:packed) => PackedItemList.t(),
          optional(:box_rotated?) => boolean()
        }

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

  @doc """
  Orientations from `generate_permutations/2` that fit within `{width, length, depth}` space.

  When a placement context (`ctx`) supplies a box, position and packed list, and the item
  implements `ExBoxPacker.ConstrainedPlacementItem` (and the box is a real box, not a
  `WorkingVolume`), each candidate is additionally filtered through the item's
  `can_be_packed?/8` hook. Port of BoxPacker's `getPossibleOrientations`.
  """
  @spec possible_orientations(Item.t(), OrientatedItem.t() | nil, dims(), ctx()) ::
          [OrientatedItem.t()]
  def possible_orientations(item, prev_item, {wl, ll, dl}, ctx \\ %{}) do
    orientations =
      item
      |> generate_permutations(prev_item)
      |> Enum.filter(fn {w, l, d} -> w <= wl and l <= ll and d <= dl end)
      |> Enum.map(fn {w, l, d} -> OrientatedItem.new(item, w, l, d) end)

    apply_constraint_filter(orientations, item, ctx)
  end

  # Mirror OrientatedItemFactory::getPossibleOrientations: only filter when the item
  # implements ConstrainedPlacementItem AND the box is a real box (not a WorkingVolume).
  defp apply_constraint_filter(orientations, item, ctx) do
    box = Map.get(ctx, :box)

    if constrained?(item, box) do
      packed = Map.get(ctx, :packed, PackedItemList.new())
      x = Map.get(ctx, :x, 0)
      y = Map.get(ctx, :y, 0)
      z = Map.get(ctx, :z, 0)
      box_rotated? = Map.get(ctx, :box_rotated?, false)

      Enum.filter(orientations, &can_be_packed?(&1, box, x, y, z, packed, box_rotated?))
    else
      orientations
    end
  end

  defp constrained?(item, box) do
    ConstrainedPlacementItem.impl_for(item) != nil and box != nil and
      not is_struct(box, WorkingVolume)
  end

  # boxIsRotated coordinate swap: build a rotated packed list (x<->y, width<->length) and
  # query with swapped position/dimensions, matching OrientatedItemFactory.php exactly.
  defp can_be_packed?(orientation, box, x, y, z, packed, true) do
    rotated = rotate_packed_list(packed)

    ConstrainedPlacementItem.can_be_packed?(
      orientation.item,
      PackedBox.new(box, rotated),
      y,
      x,
      z,
      orientation.length,
      orientation.width,
      orientation.depth
    )
  end

  defp can_be_packed?(orientation, box, x, y, z, packed, false) do
    ConstrainedPlacementItem.can_be_packed?(
      orientation.item,
      PackedBox.new(box, packed),
      x,
      y,
      z,
      orientation.width,
      orientation.length,
      orientation.depth
    )
  end

  defp rotate_packed_list(%PackedItemList{items: items}) do
    items
    |> Enum.reverse()
    |> Enum.reduce(PackedItemList.new(), fn it, acc ->
      PackedItemList.insert(
        acc,
        PackedItem.new(it.item, it.y, it.x, it.z, it.length, it.width, it.depth)
      )
    end)
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
    # Mirror PHP passing new PackedItemList() with x=y=z=0 and box_rotated?=false.
    item
    |> possible_orientations(
      nil,
      {Box.inner_width(box), Box.inner_length(box), Box.inner_depth(box)},
      %{box: box, x: 0, y: 0, z: 0, packed: PackedItemList.new(), box_rotated?: false}
    )
    |> Enum.any?(&OrientatedItem.stable?/1)
  end

  @doc """
  The best orientation for `item` in the given remaining space, or `nil` if none fit.
  `next_items` are the remaining items (extract order) used for the look-ahead tiebreaker;
  `row_length` and `single_pass?` feed the look-ahead simulation. `x`/`y`/`z`, `packed` and
  `box_rotated?` carry the placement context so per-placement constraints are honoured (and
  are threaded through to the sorter's look-ahead of the next item).
  """
  @spec best_orientation(
          Box.t(),
          Item.t(),
          OrientatedItem.t() | nil,
          dims(),
          [Item.t()],
          integer(),
          boolean(),
          boolean(),
          integer(),
          integer(),
          integer(),
          PackedItemList.t(),
          boolean()
        ) :: OrientatedItem.t() | nil
  # 13 parameters is a faithful 1:1 port of BoxPacker's getBestOrientation signature plus
  # the box_rotated? flag carried on the factory instance in PHP.
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def best_orientation(
        box,
        item,
        prev_item,
        {wl, ll, dl} = space,
        next_items,
        row_length,
        single_pass?,
        consider_stability?,
        x,
        y,
        z,
        packed,
        box_rotated?
      ) do
    placement = %{box: box, x: x, y: y, z: z, packed: packed, box_rotated?: box_rotated?}
    possible = possible_orientations(item, prev_item, space, placement)
    usable = if consider_stability?, do: usable_orientations(box, item, possible), else: possible

    case usable do
      [] ->
        nil

      orientations ->
        ctx = %{
          box: box,
          width_left: wl,
          length_left: ll,
          depth_left: dl,
          next_items: next_items,
          row_length: row_length,
          single_pass?: single_pass?,
          x: x,
          y: y,
          z: z,
          packed: packed,
          box_rotated?: box_rotated?
        }

        orientations
        |> OrientatedItemSorter.sort(ctx)
        |> hd()
    end
  end
end

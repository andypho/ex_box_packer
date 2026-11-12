defmodule ExBoxPacker.Engine.VoidFinder do
  @moduledoc false
  # Finds empty rectangular regions inside a box given already-packed items. Port of
  # BoxPacker's `VoidFinder` (4.3.0).
  #
  # Starts from the full working volume, then for each packed item replaces every free region
  # that intersects it with up to six leftover pieces (left, right, front, back, below,
  # above). The result includes both exterior leftovers and internal voids. Regions may
  # overlap each other; they never overlap a packed item.
  #
  # Dimensions are the working width/length/depth used by layer packing (width and length are
  # swapped when the box is evaluated rotated), not necessarily the box's own inner sizes.
  # Output order matters: VolumePacker.fill_voids walks it after a stable sort, so both
  # functions keep BoxPacker's exact ordering.

  alias ExBoxPacker.Engine.VoidSpace
  alias ExBoxPacker.Result.PackedItem

  @doc "Free regions in a `width x length x depth` volume holding `packed_items`."
  @spec find(integer(), integer(), integer(), [PackedItem.t()]) :: [VoidSpace.t()]
  def find(width, length, depth, packed_items),
    do: subtract_items([VoidSpace.new(0, 0, 0, width, length, depth)], packed_items)

  @doc "Refine an existing set of free regions by carving out each of `packed_items`."
  @spec subtract_items([VoidSpace.t()], [PackedItem.t()]) :: [VoidSpace.t()]
  def subtract_items(spaces, packed_items) do
    Enum.reduce(packed_items, spaces, fn item, acc ->
      Enum.flat_map(acc, &subtract_item(&1, item))
    end)
  end

  defp subtract_item(space, item) do
    if overlaps?(space, item), do: residuals(space, item), else: [space]
  end

  defp overlaps?(space, item) do
    item.x < space.x + space.width and item.x + item.width > space.x and
      item.y < space.y + space.length and item.y + item.length > space.y and
      item.z < space.z + space.depth and item.z + item.depth > space.z
  end

  # Up to six pieces around the part of `item` inside `space` (left, right, front, back,
  # below, above; no gaps, no double-counting). A piece exists only when the item stops
  # short of that side; every void and overlap has positive extent on the other two axes,
  # so "volume > 0" is exactly PHP's per-side check.
  defp residuals(space, item) do
    space_end_x = space.x + space.width
    space_end_y = space.y + space.length
    space_end_z = space.z + space.depth
    ox = max(space.x, item.x)
    oy = max(space.y, item.y)
    oz = max(space.z, item.z)
    o_end_x = min(space_end_x, item.x + item.width)
    o_end_y = min(space_end_y, item.y + item.length)
    o_end_z = min(space_end_z, item.z + item.depth)
    ow = o_end_x - ox
    ol = o_end_y - oy

    Enum.filter(
      [
        VoidSpace.new(space.x, space.y, space.z, ox - space.x, space.length, space.depth),
        VoidSpace.new(
          o_end_x,
          space.y,
          space.z,
          space_end_x - o_end_x,
          space.length,
          space.depth
        ),
        VoidSpace.new(ox, space.y, space.z, ow, oy - space.y, space.depth),
        VoidSpace.new(ox, o_end_y, space.z, ow, space_end_y - o_end_y, space.depth),
        VoidSpace.new(ox, oy, space.z, ow, ol, oz - space.z),
        VoidSpace.new(ox, oy, o_end_z, ow, ol, space_end_z - o_end_z)
      ],
      &(&1.volume > 0)
    )
  end
end

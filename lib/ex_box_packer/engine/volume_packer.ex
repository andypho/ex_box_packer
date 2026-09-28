defmodule ExBoxPacker.Engine.VolumePacker do
  @moduledoc """
  Packs items into a single box. Functional port of BoxPacker's `VolumePacker`. Tries both
  box footprint rotations (unless single-pass or the item set forbids rotation) and each
  special first-item orientation, returning the permutation that packs the most (an exact
  full pack short-circuits; otherwise highest volume utilisation).
  """

  alias ExBoxPacker.{Box, ConstrainedPlacementItem, Item}

  alias ExBoxPacker.Engine.{
    Cache,
    ItemList,
    ItemSpec,
    LayerPacker,
    LayerStabiliser,
    OrientatedItemFactory,
    VoidFinder
  }

  alias ExBoxPacker.Result.{PackedBox, PackedItem, PackedItemList, PackedLayer}

  @doc """
  Pack `items` into `box`. `opts`: `single_pass?` (default false), `strict_ordering?`
  (default false). Returns a `PackedBox` (items that don't fit are simply absent).
  """
  @spec pack(Box.t(), [Item.t() | ItemSpec.t()], keyword()) :: PackedBox.t()
  def pack(box, items, opts \\ []) do
    # When called nested (from Packer or the look-ahead) `with_cache` detects the existing
    # cache and is a no-op wrapper, so the whole pack tree shares ONE cache.
    Cache.with_cache(fn -> do_pack(box, items, opts) end)
  end

  defp do_pack(box, items, opts) do
    single_pass? = Keyword.get(opts, :single_pass?, false)
    strict? = Keyword.get(opts, :strict_ordering?, false)
    sorted = ItemList.from_items(items)

    pack_across_width_only? = single_pass?
    has_no_rotation? = Enum.any?(sorted, &(&1.rotation == :never))

    has_constrained_items? =
      Enum.any?(sorted, &(ConstrainedPlacementItem.impl_for(&1.item) != nil))

    packer_opts = %{
      box: box,
      single_pass?: single_pass?,
      strict_ordering?: strict?,
      has_constrained_items?: has_constrained_items?,
      box_rotated?: false
    }

    rotations =
      if not pack_across_width_only? and not has_no_rotation?, do: [false, true], else: [false]

    permutations =
      Enum.flat_map(rotations, fn rotated? ->
        {box_width, box_length} =
          if rotated?,
            do: {Box.inner_length(box), Box.inner_width(box)},
            else: {Box.inner_width(box), Box.inner_length(box)}

        # setBoxIsRotated: true when the tried footprint width differs from the box's own.
        rotation_opts = %{packer_opts | box_rotated?: Box.inner_width(box) != box_width}

        first_item_orientations =
          first_item_orientations(single_pass?, sorted, box, box_width, box_length)

        Enum.map(first_item_orientations, fn first ->
          pack_rotation(rotation_opts, sorted, box, box_width, box_length, first)
        end)
      end)

    # short-circuit: any permutation that packs everything
    full = Enum.find(permutations, fn pb -> PackedItemList.count(pb.items) == length(sorted) end)

    full ||
      permutations
      |> Enum.sort_by(&PackedBox.volume_utilisation/1, :desc)
      |> hd()
  end

  # The orientation of the first item can have an outsized effect on the rest of the
  # placement, so (unless single-pass) try every orientation it could take against the
  # empty box footprint.
  defp first_item_orientations(single_pass?, sorted, _box, _box_width, _box_length)
       when single_pass? or sorted == [],
       do: [nil]

  defp first_item_orientations(_single_pass?, sorted, box, box_width, box_length) do
    # Mirror VolumePacker::pack: the first-item probe uses a fresh factory (boxIsRotated
    # defaults to false) with an empty packed list at the origin, so constraints are still
    # evaluated for a constrained first item.
    placement = %{box: box, x: 0, y: 0, z: 0, packed: PackedItemList.new(), box_rotated?: false}

    case OrientatedItemFactory.possible_orientations(
           hd(sorted),
           nil,
           {box_width, box_length, Box.inner_depth(box)},
           placement
         ) do
      [] -> [nil]
      os -> os
    end
  end

  defp pack_rotation(opts, sorted_items, box, box_width, box_length, first_item_orientation) do
    # Rotation-invariant context threaded through the layer loop and void fill.
    rc = %{
      opts: opts,
      box: box,
      box_width: box_width,
      box_length: box_length,
      first_item_orientation: first_item_orientation
    }

    {layers, remaining} = build_layers(rc, sorted_items, [])

    layers =
      if not opts.single_pass? and layers != [] do
        layers
        |> stabilise_layers(opts)
        |> fill_voids(rc, remaining)
      else
        layers
      end

    layers = correct_layer_rotation(layers, box, box_width)
    PackedBox.new(box, packed_item_list(layers))
  end

  # Outer layer loop: preliminary depth probe, then accept-or-repack with known depth.
  # Returns the layers plus the still-unpacked queue (PHP's `$items` after the loop).
  defp build_layers(_rc, [], layers), do: {layers, []}

  defp build_layers(rc, items, layers) do
    box = rc.box
    layer_start_depth = current_packed_depth(layers)
    packed = packed_item_list(layers)
    first = if PackedItemList.count(packed) > 0, do: nil, else: rc.first_item_orientation
    remaining_depth = Box.inner_depth(box) - layer_start_depth

    {prelim_layer, prelim_remaining, _prelim_packed} =
      LayerPacker.pack_layer(
        rc.opts,
        items,
        packed,
        0,
        0,
        layer_start_depth,
        rc.box_width,
        rc.box_length,
        remaining_depth,
        0,
        true,
        first
      )

    case PackedLayer.items(prelim_layer) do
      [] ->
        {layers, items}

      prelim_items ->
        {layer, remaining} =
          finalise_layer(rc, items, packed, layer_start_depth, remaining_depth, first, %{
            prelim_layer: prelim_layer,
            prelim_items: prelim_items,
            prelim_remaining: prelim_remaining
          })

        build_layers(rc, remaining, layers ++ [layer])
    end
  end

  # If the preliminary layer's depth already matches its first-inserted item, keep it as-is;
  # otherwise re-pack with the now-known depth so shorter items can stack up from the first.
  defp finalise_layer(rc, items, packed, layer_start_depth, remaining_depth, first, prelim) do
    prelim_depth = PackedLayer.depth(prelim.prelim_layer)
    # PHP indexes getItems()[0] (first inserted, the layer's origin item at the start
    # corner). PackedLayer now stores items oldest-first (insert appends), so hd/1 is
    # exactly PHP's getItems()[0].
    first_depth = hd(prelim.prelim_items).depth

    if prelim_depth == first_depth do
      {prelim.prelim_layer, prelim.prelim_remaining}
    else
      {final_layer, final_remaining, _p} =
        LayerPacker.pack_layer(
          rc.opts,
          items,
          packed,
          0,
          0,
          layer_start_depth,
          rc.box_width,
          rc.box_length,
          remaining_depth,
          prelim_depth,
          true,
          first
        )

      {final_layer, final_remaining}
    end
  end

  defp stabilise_layers(layers, opts) do
    # Constraints include position, so reordering layers would invalidate them: skip
    # stabilisation when the item set has constrained items (or strict ordering is on),
    # matching VolumePacker::stabiliseLayers.
    if opts.has_constrained_items? or opts.strict_ordering? do
      layers
    else
      LayerStabiliser.stabilise(layers)
    end
  end

  # Having packed layers, fill any empty regions (gaps at the ends, pockets between items)
  # with the remaining items. Port of VolumePacker::fillVoids (BoxPacker 4.3.0).
  defp fill_voids(layers, rc, items) do
    packed = packed_item_list(layers)

    voids =
      VoidFinder.find(
        rc.box_width,
        rc.box_length,
        Box.inner_depth(rc.box),
        PackedItemList.sorted(packed)
      )

    do_fill_voids(layers, rc, items, packed, voids)
  end

  defp do_fill_voids(layers, _rc, [], _packed, _voids), do: layers
  defp do_fill_voids(layers, _rc, _items, _packed, []), do: layers

  defp do_fill_voids(layers, rc, items, packed, voids) do
    # Prefer lower positions, then larger free regions (volume, then footprint)
    voids = Enum.sort_by(voids, &{&1.z, -&1.volume, -&1.footprint})
    min_volume = items |> Enum.map(& &1.volume) |> Enum.min()

    case fill_first_void(voids, rc, items, packed, min_volume) do
      {:filled, layer, items, packed} ->
        voids = VoidFinder.subtract_items(voids, PackedLayer.items(layer))
        do_fill_voids(layers ++ [layer], rc, items, packed, voids)

      {:none, _items} ->
        layers
    end
  end

  # Try each void in order until one takes at least one item. A failed attempt still threads
  # its returned queue forward: like PHP's by-reference ItemList, pack_layer may have dropped
  # too-heavy items from it.
  defp fill_first_void([], _rc, items, _packed, _min_volume), do: {:none, items}

  defp fill_first_void([void | rest], rc, items, packed, min_volume) do
    # Pure performance: skip pack_layer when no remaining item can geometrically fit
    if void.volume < min_volume or not Enum.any?(items, &item_may_fit_in_void?(&1, void)) do
      fill_first_void(rest, rc, items, packed, min_volume)
    else
      {layer, items, packed} =
        LayerPacker.pack_layer(
          rc.opts,
          items,
          packed,
          void.x,
          void.y,
          void.z,
          void.x + void.width,
          void.y + void.length,
          void.depth,
          void.depth,
          # gap fill; stability assumed from surrounding geometry
          false,
          nil
        )

      case PackedLayer.items(layer) do
        [] -> fill_first_void(rest, rc, items, packed, min_volume)
        _ -> {:filled, layer, items, packed}
      end
    end
  end

  defp item_may_fit_in_void?(%{rotation: :never} = item, void),
    do: item.width <= void.width and item.length <= void.length and item.depth <= void.depth

  defp item_may_fit_in_void?(%{rotation: :keep_flat} = item, void) do
    item.depth <= void.depth and
      ((item.width <= void.width and item.length <= void.length) or
         (item.length <= void.width and item.width <= void.length))
  end

  defp item_may_fit_in_void?(%{rotation: :best_fit, sorted_dims: [a, b, c]}, void) do
    [x, y, z] = Enum.sort([void.width, void.length, void.depth])
    a <= x and b <= y and c <= z
  end

  defp correct_layer_rotation(layers, box, box_width) do
    if Box.inner_width(box) == box_width do
      layers
    else
      Enum.map(layers, &rotate_layer/1)
    end
  end

  # PHP iterates getItems() (oldest-first) and inserts (append). PackedLayer.items/1 is
  # now oldest-first and insert appends, so reduce over items as-is to preserve order.
  defp rotate_layer(layer) do
    Enum.reduce(PackedLayer.items(layer), PackedLayer.new(), fn it, acc ->
      PackedLayer.insert(
        acc,
        PackedItem.new(it.item, it.y, it.x, it.z, it.length, it.width, it.depth)
      )
    end)
  end

  defp packed_item_list(layers) do
    # PHP getPackedItemList iterates each layer's getItems() (oldest-first) and inserts.
    # PackedLayer.items/1 is now oldest-first, so iterate it directly.
    layers
    |> Enum.flat_map(&PackedLayer.items/1)
    |> Enum.reduce(PackedItemList.new(), fn it, list -> PackedItemList.insert(list, it) end)
  end

  defp current_packed_depth(layers),
    do: Enum.reduce(layers, 0, fn l, acc -> acc + PackedLayer.depth(l) end)
end

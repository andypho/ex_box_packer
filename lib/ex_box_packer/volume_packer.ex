defmodule ExBoxPacker.VolumePacker do
  @moduledoc """
  Packs items into a single box. Functional port of BoxPacker's `VolumePacker`. Tries both
  box footprint rotations (unless single-pass or the item set forbids rotation) and each
  special first-item orientation, returning the permutation that packs the most (an exact
  full pack short-circuits; otherwise highest volume utilisation).
  """

  alias ExBoxPacker.{
    Box,
    Item,
    ItemList,
    LayerPacker,
    LayerStabiliser,
    OrientatedItemFactory,
    PackedBox,
    PackedItem,
    PackedItemList,
    PackedLayer
  }

  @doc """
  Pack `items` into `box`. `opts`: `single_pass?` (default false), `strict_ordering?`
  (default false). Returns a `PackedBox` (items that don't fit are simply absent).
  """
  @spec pack(Box.t(), [Item.t()], keyword()) :: PackedBox.t()
  def pack(box, items, opts \\ []) do
    single_pass? = Keyword.get(opts, :single_pass?, false)
    strict? = Keyword.get(opts, :strict_ordering?, false)
    sorted = ItemList.from_items(items)

    pack_across_width_only? = single_pass?
    has_no_rotation? = Enum.any?(sorted, &(Item.allowed_rotation(&1) == :never))

    packer_opts = %{box: box, single_pass?: single_pass?, strict_ordering?: strict?}

    rotations =
      if not pack_across_width_only? and not has_no_rotation?, do: [false, true], else: [false]

    permutations =
      Enum.flat_map(rotations, fn rotated? ->
        {box_width, box_length} =
          if rotated?,
            do: {Box.inner_length(box), Box.inner_width(box)},
            else: {Box.inner_width(box), Box.inner_length(box)}

        first_item_orientations =
          first_item_orientations(single_pass?, sorted, box, box_width, box_length)

        Enum.map(first_item_orientations, fn first ->
          pack_rotation(packer_opts, sorted, box, box_width, box_length, first)
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
    case OrientatedItemFactory.possible_orientations(
           hd(sorted),
           nil,
           {box_width, box_length, Box.inner_depth(box)}
         ) do
      [] -> [nil]
      os -> os
    end
  end

  defp pack_rotation(opts, sorted_items, box, box_width, box_length, first_item_orientation) do
    # Rotation-invariant context threaded through the layer loop and end-gap fill.
    rc = %{
      opts: opts,
      box: box,
      box_width: box_width,
      box_length: box_length,
      first_item_orientation: first_item_orientation
    }

    layers = build_layers(rc, sorted_items, [])

    layers =
      if not opts.single_pass? and layers != [] do
        layers
        |> stabilise_layers(opts)
        |> fill_end_gaps(rc, sorted_items)
      else
        layers
      end

    layers = correct_layer_rotation(layers, box, box_width)
    PackedBox.new(box, packed_item_list(layers))
  end

  # Outer layer loop: preliminary depth probe, then accept-or-repack with known depth.
  defp build_layers(_rc, [], layers), do: layers

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
        layers

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
    # PHP indexes getItems()[0] (first inserted). PackedLayer prepends on insert, so the
    # first-inserted item is the LAST element of PackedLayer.items/1.
    first_depth = List.last(prelim.prelim_items).depth

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
    # PHP also skips stabilisation when the item set has constrained placement items;
    # ConstrainedPlacementItem support is deferred to a later milestone, so only the
    # strict-ordering guard is checked here.
    if opts.strict_ordering?, do: layers, else: LayerStabiliser.stabilise(layers)
  end

  defp fill_end_gaps(layers, rc, items) do
    # items here are the ORIGINAL sorted items; the already-packed ones must be excluded.
    remaining = remaining_after(items, layers)
    depth = Box.inner_depth(rc.box)

    max_layer_width = layers |> Enum.map(&PackedLayer.end_x/1) |> Enum.max(fn -> 0 end)

    {gap_layer1, remaining, _p} =
      LayerPacker.pack_layer(
        rc.opts,
        remaining,
        packed_item_list(layers),
        max_layer_width,
        0,
        0,
        rc.box_width,
        rc.box_length,
        depth,
        depth,
        false,
        nil
      )

    layers = layers ++ [gap_layer1]

    max_layer_length = layers |> Enum.map(&PackedLayer.end_y/1) |> Enum.max(fn -> 0 end)

    {gap_layer2, _remaining, _p} =
      LayerPacker.pack_layer(
        rc.opts,
        remaining,
        packed_item_list(layers),
        0,
        max_layer_length,
        0,
        rc.box_width,
        rc.box_length,
        depth,
        depth,
        false,
        nil
      )

    layers ++ [gap_layer2]
  end

  defp correct_layer_rotation(layers, box, box_width) do
    if Box.inner_width(box) == box_width do
      layers
    else
      Enum.map(layers, &rotate_layer/1)
    end
  end

  # PHP iterates getItems() (oldest-first) and inserts (append). PackedLayer.items/1 is
  # newest-first, and insert prepends, so reduce over items as-is to preserve order.
  defp rotate_layer(layer) do
    Enum.reduce(PackedLayer.items(layer), PackedLayer.new(), fn it, acc ->
      PackedLayer.insert(
        acc,
        PackedItem.new(it.item, it.y, it.x, it.z, it.length, it.width, it.depth)
      )
    end)
  end

  defp packed_item_list(layers) do
    layers
    |> Enum.flat_map(fn layer -> layer |> PackedLayer.items() |> Enum.reverse() end)
    |> Enum.reduce(PackedItemList.new(), fn it, list -> PackedItemList.insert(list, it) end)
  end

  defp current_packed_depth(layers),
    do: Enum.reduce(layers, 0, fn l, acc -> acc + PackedLayer.depth(l) end)

  # Items from the original sorted list that are not yet represented in the packed layers,
  # matched by identity of the underlying %Item{} struct.
  defp remaining_after(items, layers) do
    packed_items = layers |> Enum.flat_map(&PackedLayer.items/1) |> Enum.map(& &1.item)
    subtract_once(items, packed_items)
  end

  defp subtract_once(items, []), do: items
  defp subtract_once(items, [p | rest]), do: items |> delete_first(p) |> subtract_once(rest)

  defp delete_first(list, elem), do: do_delete_first(list, elem, [])
  defp do_delete_first([elem | t], elem, acc), do: Enum.reverse(acc) ++ t
  defp do_delete_first([h | t], elem, acc), do: do_delete_first(t, elem, [h | acc])
  defp do_delete_first([], _elem, acc), do: Enum.reverse(acc)
end

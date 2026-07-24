defmodule ExBoxPacker.Engine.LayerPacker do
  @moduledoc false

  alias ExBoxPacker.{Box, Item}
  alias ExBoxPacker.Engine.{OrientatedItem, OrientatedItemFactory}
  alias ExBoxPacker.Result.{PackedItem, PackedItemList, PackedLayer}

  @typedoc "Options: box, single_pass?, strict_ordering?"
  @type opts :: %{box: Box.t(), single_pass?: boolean(), strict_ordering?: boolean()}

  @doc """
  Pack a layer. Region is bounded by absolute coordinates: x runs `start_x..width_for_layer`,
  y runs `start_y..length_for_layer`, depth budget is `depth_for_layer`. `guideline_depth`
  (0 = unknown) targets a known layer depth so shorter items stack up to it.

  Returns `{%PackedLayer{}, remaining_items :: [Item.t()], %PackedItemList{}}`.
  """
  @spec pack_layer(
          opts(),
          [Item.t()],
          PackedItemList.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          boolean(),
          OrientatedItem.t() | nil
        ) :: {PackedLayer.t(), [Item.t()], PackedItemList.t()}
  # 12 parameters is a faithful 1:1 port of BoxPacker's LayerPacker::packLayer signature.
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def pack_layer(
        opts,
        items,
        packed,
        start_x,
        start_y,
        start_z,
        width_for_layer,
        length_for_layer,
        depth_for_layer,
        guideline_depth,
        consider_stability?,
        first_item
      ) do
    loop(%{
      opts: opts,
      items: items,
      packed: packed,
      layer: PackedLayer.new(),
      x: start_x,
      y: start_y,
      z: start_z,
      start_x: start_x,
      width_for_layer: width_for_layer,
      length_for_layer: length_for_layer,
      depth_for_layer: depth_for_layer,
      guideline_depth: guideline_depth,
      consider_stability?: consider_stability?,
      row_length: 0,
      prev_item: nil,
      skipped: [],
      first_item: first_item
    })
  end

  defp loop(%{items: []} = st), do: {st.layer, [], st.packed}

  defp loop(%{items: [item_to_pack | rest]} = st) do
    box = st.opts.box
    weight_budget = Box.max_weight(box) - Box.empty_weight(box) - PackedItemList.weight(st.packed)

    if Item.weight(item_to_pack) > weight_budget do
      # too heavy to ever fit — drop and continue
      loop(%{st | items: rest})
    else
      {orientation, first_item} =
        if match?(%OrientatedItem{}, st.first_item) and st.first_item.item == item_to_pack do
          {st.first_item, nil}
        else
          space = {st.width_for_layer - st.x, st.length_for_layer - st.y, st.depth_for_layer}

          oi =
            OrientatedItemFactory.best_orientation(
              box,
              item_to_pack,
              st.prev_item,
              space,
              rest,
              st.row_length,
              st.opts.single_pass?,
              st.consider_stability?
            )

          {oi, st.first_item}
        end

      case orientation do
        %OrientatedItem{} = oi -> place(st, item_to_pack, rest, oi, first_item)
        nil -> no_fit(st, item_to_pack, rest, first_item)
      end
    end
  end

  defp place(st, _item_to_pack, rest, oi, first_item) do
    packed_item = PackedItem.new(oi.item, st.x, st.y, st.z, oi.width, oi.length, oi.depth)
    layer = PackedLayer.insert(st.layer, packed_item)
    packed = PackedItemList.insert(st.packed, packed_item)
    row_length = max(st.row_length, packed_item.length)

    # Stack shorter items on top, up to the guideline/known layer depth
    base_depth =
      if st.guideline_depth != 0, do: st.guideline_depth, else: PackedLayer.depth(layer)

    stackable_depth = base_depth - packed_item.depth

    {layer, items_after_stack, packed} =
      if stackable_depth > 0 do
        {stacked, items2, packed2} =
          pack_layer(
            st.opts,
            rest,
            packed,
            st.x,
            st.y,
            st.z + packed_item.depth,
            st.x + packed_item.width,
            st.y + packed_item.length,
            stackable_depth,
            stackable_depth,
            st.consider_stability?,
            nil
          )

        {PackedLayer.merge(layer, stacked), items2, packed2}
      else
        {layer, rest, packed}
      end

    new_x = st.x + packed_item.width

    # Fill lengthwise across the width of this item, up to the current row length
    {length_fill, items_after_length, packed} =
      pack_layer(
        st.opts,
        items_after_stack,
        packed,
        new_x - packed_item.width,
        st.y + packed_item.length,
        st.z,
        new_x,
        st.y + row_length,
        st.depth_for_layer,
        PackedLayer.depth(layer),
        st.consider_stability?,
        nil
      )

    layer = PackedLayer.merge(layer, length_fill)

    {items_next, skipped_next} =
      if items_after_length == [] and st.skipped != [] do
        {st.skipped ++ items_after_length, []}
      else
        {items_after_length, st.skipped}
      end

    loop(%{
      st
      | items: items_next,
        packed: packed,
        layer: layer,
        x: new_x,
        row_length: row_length,
        prev_item: oi,
        first_item: first_item,
        skipped: skipped_next
    })
  end

  defp no_fit(st, item_to_pack, rest, first_item) do
    cond do
      not st.opts.strict_ordering? and rest != [] ->
        # skip for now; also skip any immediately-following identical items (but never the last)
        {also_skipped, rest2} = skip_same_dimensions(item_to_pack, rest)

        loop(%{
          st
          | items: rest2,
            skipped: st.skipped ++ [item_to_pack] ++ also_skipped,
            first_item: first_item
        })

      st.x > st.start_x ->
        # no more fits width-wise: start a new row
        loop(%{
          st
          | items: st.skipped ++ [item_to_pack] ++ rest,
            y: st.y + st.row_length,
            x: st.start_x,
            row_length: 0,
            skipped: [],
            prev_item: nil,
            first_item: first_item
        })

      true ->
        # nothing fits at all: end this layer, return unpacked items to the caller
        {st.layer, st.skipped ++ [item_to_pack] ++ rest, st.packed}
    end
  end

  # Pop leading items that share dimensions with `item` (leaving at least one), per PHP's
  # `while (items.count() > 1 && isSameDimensions(...))`.
  defp skip_same_dimensions(item, items), do: do_skip(item, items, [])

  defp do_skip(item, [h | t] = items, acc) do
    if t != [] and same_dimensions?(item, h) do
      do_skip(item, t, [h | acc])
    else
      {Enum.reverse(acc), items}
    end
  end

  defp do_skip(_item, [], acc), do: {Enum.reverse(acc), []}

  defp same_dimensions?(a, b) do
    Enum.sort([Item.width(a), Item.length(a), Item.depth(a)]) ==
      Enum.sort([Item.width(b), Item.length(b), Item.depth(b)])
  end
end

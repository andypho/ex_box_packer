defmodule ExBoxPacker do
  @moduledoc """
  A faithful Elixir port of [BoxPacker](https://github.com/dvdoug/BoxPacker) (PHP, v4.2.0), a 3D
  bin-packing and box-selection engine. Given a set of items and a catalog of candidate boxes, it
  chooses which boxes to use and computes how to physically arrange the items inside each one:
  orthogonal rotation (`:never` / `:keep_flat` / `:best_fit`), per-box weight limits, weight
  redistribution across boxes, stability, and optional placement constraints.

  Beyond simple packing, the engine supports the same extension points as the original library:
  limited box supply, constrained placement (`ExBoxPacker.ConstrainedPlacementItem`), linked item
  groups that must ship together (`ExBoxPacker.LinkedItem`), and a packing timeout. All geometry is
  integer-only — pick a unit (e.g. millimetres and grams) and use it consistently.

  ## Example

  Pack items into the fewest boxes with `ExBoxPacker.Packer.pack/2`, using the built-in
  `ExBoxPacker.SimpleBox` and `ExBoxPacker.SimpleItem` structs:

      alias ExBoxPacker.{Packer, SimpleBox, SimpleItem}

      boxes = [
        %SimpleBox{
          reference: "small",
          outer_width: 100, outer_length: 100, outer_depth: 100,
          inner_width: 96, inner_length: 96, inner_depth: 96,
          empty_weight: 10, max_weight: 1000
        }
      ]

      items = [
        %SimpleItem{
          description: "widget",
          width: 50, length: 50, depth: 50,
          weight: 100, allowed_rotation: :best_fit, quantity: 3
        }
      ]

      {:ok, result} = Packer.pack(boxes, items)

  On success `pack/2` returns `{:ok, %ExBoxPacker.Result.PackedBoxList{}}`; when some items cannot
  be placed it returns `{:error, %ExBoxPacker.NoBoxesAvailableError{}}`.
  """

  use Boundary,
    deps: [],
    exports: [
      Packer,
      Engine.VolumePacker,
      Item,
      Box,
      ConstrainedPlacementItem,
      LinkedItem,
      LimitedSupplyBox,
      SimpleItem,
      SimpleBox,
      Rotation,
      Result.PackedBox,
      Result.PackedBoxList,
      Result.PackedItem,
      Result.PackedItemList,
      NoBoxesAvailableError,
      TimeoutError,
      Sorting.ItemSorter,
      Sorting.DefaultItemSorter,
      Sorting.BoxSorter,
      Sorting.DefaultBoxSorter,
      Sorting.PackedBoxSorter,
      Sorting.DefaultPackedBoxSorter
    ]
end

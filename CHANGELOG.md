# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-27

Initial release: a feature-complete, faithful Elixir port of
[BoxPacker](https://github.com/dvdoug/BoxPacker) (PHP, v4.2.0).

### Added

- **Domain layer.** `ExBoxPacker.Item` / `ExBoxPacker.Box` protocols with the built-in
  `ExBoxPacker.SimpleItem` and `ExBoxPacker.SimpleBox` structs, integer-only geometry,
  `ExBoxPacker.Rotation` modes (`:never`, `:keep_flat`, `:best_fit`), pluggable sorters
  (`ItemSorter`, `BoxSorter`, `PackedBoxSorter` with default implementations), and the
  `Packed*` result structs (`PackedBox`, `PackedBoxList`, `PackedItem`, `PackedItemList`).
- **Single-box packing.** `ExBoxPacker.Engine.VolumePacker` arranges items within one box —
  orthogonal rotation, per-box weight limits, layer packing, and stability.
- **Multi-box selection.** `ExBoxPacker.Packer.pack/2`, `pack!/2`, and `pack_all_possible/2`
  perform greedy catalog box selection, choosing the fewest boxes to hold all items.
- **Weight redistribution.** Post-pack rebalancing of item weight across boxes for more even
  parcels.
- **Constraints and extension protocols:**
  - Limited box supply via `ExBoxPacker.LimitedSupplyBox` (boxes are used only up to their
    available quantity; unimplemented boxes are treated as unlimited).
  - Constrained placement via `ExBoxPacker.ConstrainedPlacementItem` (per-placement rules such
    as max-quantity-per-box or no-stacking).
  - Linked item groups via `ExBoxPacker.LinkedItem` (members of a named group are never split
    across boxes).
  - Packing timeout via the `:timeout` option, raising `ExBoxPacker.TimeoutError` once the
    deadline is exceeded.

[0.1.0]: https://github.com/andypho/ex_box_packer/releases/tag/v0.1.0

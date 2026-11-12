# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Now tracks BoxPacker v4.3.0 (previously v4.2.0). Packing results change for some inputs:
generally more items fit per box and weight is balanced more evenly across boxes.

### Changed

- **Void filling** — after packing layers, the packer now fills any empty region left in
  the box (pockets between items as well as gaps at the far ends), so more items fit in some
  boxes (BoxPacker issues #214, #609).
- **Orientation choice** — when every remaining item is the same size, the packer prefers
  the orientation that fits more of them in the free space. Slab-like `:best_fit` items
  (thinnest edge at most 30% of the longest) prefer lying flat. The look-ahead now
  considers the next 7 items instead of 8 (BoxPacker #227, #268, #334, #366).
- **Linked items** — the default item sort now keeps each `ExBoxPacker.LinkedItem` group
  together (ungrouped items first, then groups in identifier order, with numeric identifiers
  compared as numbers, so `"9"` comes before `"10"`). Previously, groups of similar items could
  interleave until no candidate box held a complete group (BoxPacker #664).
- `ExBoxPacker.Result.PackedBox.validate/1` also returns
  `{:error, {:overweight, weight, max_weight}}` when a box is over its maximum weight.

### Fixed

- Weight redistribution now matches BoxPacker in two edge cases: when a move between
  boxes can only be half completed, and when the second box of a pair is the heavier one.
  The e-commerce golden benchmark now matches BoxPacker in all 4,288 scenarios in both 2D
  and 3D (previously 4,283 and 4,278).
- Weight redistribution repacks boxes with the default packed-box sorter, as BoxPacker does.
  A custom `:packed_box_sorter` now only orders the final result; previously it also changed
  which box each repack chose.
- Items that tie on volume and weight are ordered by description the way BoxPacker does:
  numeric descriptions compare as numbers (`"9"` before `"10"`).

## [0.2.1] - 2026-09-08

No functional changes — `lib/` and `priv/` are untouched since 0.2.0. Documentation,
tooling and test coverage only.

### Added

- **Dev preview guide** (`guides/dev_preview.md`) — how to mount the
  `ExBoxPacker.PackerPreview` route in a host application.

### Changed

- Attribution for the bundled three.js build in `LICENSE` and `README.md`.
- Coverage reporting: CI now uploads to Codecov via excoveralls, and test coverage
  rose from 92.3% to 98.4%.
- Dependency bumps — `absinthe` 1.11.0 → 1.12.0 (optional), `dialyxir` 1.4.7 → 1.4.8,
  `ex_doc` 0.40.3 → 0.40.4. The requirements in `mix.exs` are unchanged, so consumers
  are unaffected.

## [0.2.0] - 2026-08-06

### Changed

- **Breaking — configuration consolidated under a single key.** All library
  configuration now lives under the `ExBoxPacker` application-config key, with nested
  `preview:` / `broadcast:` sub-keywords, read through the new `ExBoxPacker.Config`
  helper.

  Upgrade — replace the old preview key:

  ```elixir
  # before
  config :ex_box_packer, ExBoxPacker.Preview, enabled: true

  # after
  config :ex_box_packer, ExBoxPacker, preview: [enabled: true]
  ```

### Added

- **Config-driven event broadcasting (`ExBoxPacker.Broadcast`).** When a
  `:broadcast_topic` is passed to `ExBoxPacker.Packer.pack/3` or `pack_all_possible/3`
  and a `broadcast:` config is set, packing emits `:started`, `:box_packed` (one per
  box, in placement order), and `:done` events — published to an Absinthe subscription
  via `Absinthe.Subscription.publish/3`. No callbacks; it is entirely config-driven.
  Adds an optional `:absinthe` dependency, guarded so a `nil` topic or absent config
  makes it a cheap no-op — existing `pack/2,3` callers are unaffected.
- **`ExBoxPacker.Config`** — reader for the consolidated config (`preview/0`,
  `broadcast/0`).
- **`ExBoxPacker.Broadcast.Event`** — the streamed event struct
  (`:started` / `:box_packed` / `:done`, carrying the packed box or summary).
- **`:broadcast_topic` option** on `ExBoxPacker.Packer.pack/3` and
  `pack_all_possible/3`.

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

[0.2.1]: https://github.com/andypho/ex_box_packer/releases/tag/v0.2.1
[0.2.0]: https://github.com/andypho/ex_box_packer/releases/tag/v0.2.0
[0.1.0]: https://github.com/andypho/ex_box_packer/releases/tag/v0.1.0

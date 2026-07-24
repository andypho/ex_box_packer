# ExBoxPacker

A faithful Elixir port of [dvdoug/BoxPacker](https://github.com/dvdoug/BoxPacker) (PHP, v4.2.0) — a 3D
bin-packing and box-selection engine. Given a set of items and a catalog of boxes, it decides which boxes to use and
how to physically arrange the items inside them (rotation, weight limits, weight distribution, stability, and
placement constraints).

> **Status: under construction.** Milestone 1 (the domain layer) is in progress. The packing engine
> (`VolumePacker`, `Packer`) lands in later milestones — see `docs/superpowers/plans/`.

## Requirements

- Elixir `~> 1.20` on OTP 29 (pinned in `.tool-versions` for [`mise`](https://mise.jdx.dev)).

If you use `mise`, the toolchain is selected automatically inside this directory:

```bash
mise install        # installs the pinned erlang/elixir the first time
```

## Getting started

```bash
mise install                 # once, to install the pinned toolchain
mix deps.get                 # fetch dev/test deps (ex_doc, credo, dialyxir, stream_data)
mix test                     # run the test suite
iex -S mix                   # interactive shell with all modules loaded
```

If `mix`/`iex` aren't on your PATH (mise not activated in your shell), prefix commands with `mise exec -- `,
e.g. `mise exec -- iex -S mix`.

Inside `iex`, use `recompile()` after editing source.

## Usage (target API — not all implemented yet)

```elixir
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
  %SimpleItem{description: "widget", width: 50, length: 50, depth: 50,
              weight: 100, allowed_rotation: :best_fit, quantity: 3}
]

{:ok, result} = Packer.pack(boxes, items)   # (Packer arrives in Milestone 3)
```

Today (Milestone 1) the domain layer is usable directly: `ExBoxPacker.SimpleItem`, `SimpleBox`, the `Item`/`Box`
protocols, `Rotation`, the sorters, and the `Packed*` result structs.

## Important notes

- **Integer-only geometry.** All dimensions and weights are integers. Pick a unit (e.g. mm and grams) and use it
  consistently across every item and box. This is BoxPacker's core correctness rule and is enforced at the struct
  boundary.
- **Rotation modes** (`ExBoxPacker.Rotation`): `:never` (fixed), `:keep_flat` (rotate in the horizontal plane
  only — "this way up"), `:best_fit` (all 6 orthogonal orientations, the default).
- **Boxes:** outer dimensions/empty weight are for shipping; inner dimensions bound the packable space.
- **Item quantity:** `SimpleItem`'s `quantity` field is a convenience expanded to N identical units. Custom `Item`
  implementations supply one struct per physical unit.
- **Extensibility:** custom items/boxes implement the `ExBoxPacker.Item` / `ExBoxPacker.Box` protocols. Later
  milestones add optional protocols for constrained placement, limited supply, and linked items.

## License

MIT. This project is a port of BoxPacker (also MIT), © Doug Wright and contributors.

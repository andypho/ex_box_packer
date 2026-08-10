# ExBoxPacker

A faithful Elixir port of [dvdoug/BoxPacker](https://github.com/dvdoug/BoxPacker) (PHP, v4.2.0) — a 3D
bin-packing and box-selection engine. Given a set of items and a catalog of boxes, it decides which boxes to use and
how to physically arrange the items inside them (rotation, weight limits, weight distribution, stability, and
placement constraints).

## Installation

Install from [Hex.pm](https://hex.pm/packages/ex_box_packer):

```elixir
def deps do
  [{:ex_box_packer, "~> 0.2.0"}]
end
```

Note: ExBoxPacker requires Elixir 1.15 or higher.

## Upgrading

See [CHANGELOG](./CHANGELOG.md) for upgrade steps between versions.

## Documentation

- [ExBoxPacker hexdocs](https://hexdocs.pm/ex_box_packer).
- For the packing algorithm, constraints, and general background, see the original
  [BoxPacker](https://github.com/dvdoug/BoxPacker) project and its
  [documentation](https://boxpacker.io).

## Requirements

- **Supported:** Elixir `~> 1.15` (the `mix.exs` requirement — kept low so apps on older Elixir can depend on it).
- **Developed and tested with:** Elixir `1.20.2` on OTP 29, pinned in `.tool-versions`.

The `.tool-versions` file is read by both [`asdf`](https://asdf-vm.com) and [`mise`](https://mise.jdx.dev), so
either one selects the pinned dev toolchain automatically inside this directory:

```bash
# mise
mise install                 # installs the pinned erlang/elixir the first time

# asdf
asdf plugin add erlang       # once, if the plugins aren't already added
asdf plugin add elixir
asdf install                 # installs the pinned erlang/elixir from .tool-versions
```

## Getting started

```bash
mise install                 # once, to install the pinned toolchain (or `asdf install`)
mix deps.get                 # fetch deps (ex_doc, credo, dialyxir, stream_data, boundary, plug)
mix test                     # run the test suite
iex -S mix                   # interactive shell with all modules loaded
```

If you use asdf, run `asdf install` in place of `mise install`; asdf exposes `mix`/`iex` on your PATH via shims.
With mise, if `mix`/`iex` aren't on your PATH (mise not activated in your shell), prefix commands with
`mise exec -- `, e.g. `mise exec -- iex -S mix`.

Inside `iex`, use `recompile()` after editing source.

## Usage

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

{:ok, result} = Packer.pack(boxes, items)
```

The public API is `ExBoxPacker.Packer` (`pack/2`, `pack!/2`, `pack_all_possible/2`), the `SimpleItem` / `SimpleBox`
structs, the `Item` / `Box` protocols (plus optional protocols for constrained placement, limited supply, and linked
items), `Rotation`, the sorters, and the `Packed*` result structs.

## Important notes

- **Units — millimetres and grams; no conversion.** By convention all lengths (widths, lengths, depths) are in
  millimetres (`mm`) and all weights (item weight, box empty weight, max weight) are in grams (`g`) — the same
  convention as BoxPacker. Dimensions and weights are plain integers, and to stay lightweight the library does
  **no unit conversion**: it treats every value as a raw magnitude, so all items and boxes must share the same
  units. If your data is in other units (cm, inches, kg, …), convert it to mm/g at your own boundary before packing.
  Using consistent units is BoxPacker's core correctness rule.
- **Rotation modes** (`ExBoxPacker.Rotation`): `:never` (fixed), `:keep_flat` (rotate in the horizontal plane
  only — "this way up"), `:best_fit` (all 6 orthogonal orientations, the default).
- **Boxes:** outer dimensions/empty weight are for shipping; inner dimensions bound the packable space.
- **Item quantity:** `SimpleItem`'s `quantity` field is a convenience expanded to N identical units. Custom `Item`
  implementations supply one struct per physical unit.
- **Extensibility:** custom items/boxes implement the `ExBoxPacker.Item` / `ExBoxPacker.Box` protocols. Optional
  protocols add constrained placement, limited supply, and linked items.

## License

MIT. This project is a port of BoxPacker (also MIT), © Doug Wright and contributors.
The optional 3D preview bundles [three.js](https://threejs.org) (also MIT), © Three.js Authors.

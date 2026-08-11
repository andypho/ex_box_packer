# Dev preview

`ExBoxPacker.PackerPreview` is a `forward`-able Plug you mount in your own app: a browser tool that packs a spec you
type in using the real engine and animates the result in 3D, in placement order. Use it to try box catalogs, reproduce
a bad packing, or just get a feel for how the packer behaves.

## 1. Make sure `:plug` is available

`:plug` is an optional dependency and `ExBoxPacker.PackerPreview` only compiles when Plug is loaded. Phoenix apps
already have it; otherwise add `{:plug, "~> 1.15"}` to your deps.

## 2. Start the collector (dev only)

The tool reads from `ExBoxPacker.Preview.Collector`, an in-memory ring buffer of recent packings. The route needs it
running — add it to your supervision tree in dev:

```elixir
# config/dev.exs
config :ex_box_packer, ExBoxPacker, preview: [enabled: true, max_packings: 50]

# lib/my_app/application.ex
children =
  [MyApp.Repo, MyAppWeb.Endpoint] ++
    if ExBoxPacker.Preview.enabled?(), do: [ExBoxPacker.Preview.Collector], else: []
```

`enabled: true` gates `ExBoxPacker.Preview.capture/2` (see below) and is what the snippet above keys off;
`max_packings` sizes the buffer (default 50).

## 3. Mount the route

```elixir
# lib/my_app_web/router.ex
if Application.compile_env(:my_app, :dev_routes) do
  scope "/dev" do
    forward "/box-packer", ExBoxPacker.PackerPreview
  end
end
```

Mount it **outside** any `protect_from_forgery` (CSRF) pipeline — a scope with no `:browser` pipeline is ideal, the
same way Swoosh's mailbox and Phoenix's GraphiQL are mounted. Inside a CSRF pipeline the JavaScript assets still load,
but `POST /api/pack` is rejected unless the request carries a valid CSRF token. In a plain Plug router:

```elixir
forward("/dev/box-packer", to: ExBoxPacker.PackerPreview)
```

Then visit <http://localhost:4000/dev/box-packer>.

## What you can do there

- **Build a packing** — "＋ New packing" opens a form. Add box rows (Australia Post Small / Medium / Large / X-Large
  presets, or Custom) and item rows (description, W/L/D, weight, quantity, rotation mode). "Pack ▶" runs
  `Packer.pack/2` server-side and shows the result; validation errors come back inline.
- **Load example** — one click fills the form with a packable sample spec to start from.
- **Replay the packing** — Play / Step / scrub through the items in the order the packer placed them, with a speed
  slider. This is the fastest way to see _why_ an item ended up where it did.
- **Inspect in 3D** — drag to orbit, wheel or `+` / `−` to zoom, and switch between boxes with the dropdown.
- **Packings list** — recent packings, newest first, labelled `label — Nb/Ni/U%` (boxes / items / volume utilisation).
  New ones stream in live over Server-Sent Events, so a pack triggered from `iex` or a request shows up immediately.

## Capture packings from your own code

The sandbox packs specs you type in. To view real packings your app produced, capture them:

```elixir
{:ok, result} = ExBoxPacker.Packer.pack(boxes, items)
ExBoxPacker.Preview.capture(result, label: "order #123")

# or in one step
{:ok, result} = ExBoxPacker.Preview.pack(boxes, items, label: "order #123")
```

`capture/2` is a cheap no-op when preview is disabled or the collector isn't running, so it is safe to leave in code
paths shared with production.

## Notes and limits

- **Dev only, no auth.** Anyone who can reach the route can run packings and read every captured packing. Keep it
  behind a `dev_routes` flag or your own auth plug.
- **In memory only.** The last `max_packings` packings are held in the collector process and lost on restart.
- **Sandbox input is mm / g integers**, and every sandbox box is validated against Australia Post "Within Australia"
  parcel limits: longest side ≤ 1050 mm, volume ≤ 0.25 m³, max weight ≤ 22 kg. Sandbox boxes use inner = outer
  dimensions and `empty_weight: 0`. `Preview.capture/2` applies none of these limits — it renders whatever you packed.
- **Offline.** three.js is bundled in `priv/static/preview`; the tool loads nothing from a CDN.

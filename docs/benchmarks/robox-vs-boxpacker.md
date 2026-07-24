# Benchmark: robox vs BoxPacker — single box, N items

**Date:** 2026-07-24

A head-to-head comparison of two 3D bin packers on the same task: fit the first *N* of a fixed item set into
**one** box, and measure how many items fit, the volume utilisation, and wall-clock time.

- **[robox](https://github.com/gyang274/gbp)** — pure Elixir (BEAM), extreme-point heuristic + entropy ("best
  information score") fit, branch-and-bound with adaptive beam. `Robox.pack(items, [bin], :gbp4d)`.
- **[BoxPacker](https://github.com/dvdoug/BoxPacker)** — PHP, layer/wall-building constructive heuristic with
  look-ahead. `VolumePacker` into a single box. This is the library `ex_box_packer` ports.

## Why this comparison

`robox` is an existing pure-Elixir 3D bin packer, so it's the natural point of reference for `ex_box_packer`. They
use **different algorithms** and, it turns out, optimize **different objectives** in practice. See the takeaways for
how this informs `ex_box_packer`'s direction.

## Method

- **Identical inputs** for both tools, read from shared CSVs (`box.csv`, `items_all.csv`).
- Box: **100 × 100 × 100**, `max_weight` set high so weight never binds.
- Items: 80 with random integer dimensions; each run uses the first *N* (nested). Weight = 1 each.
  Total item volume ≈ 420–450 % of box volume, so overflow is forced for larger *N*.
- **Full 6-way rotation** enabled on both sides (`Rotation::BestFit` for BoxPacker; robox always allows 6).
- Fairness: **items-fit** and **volume-utilisation** are directly comparable (identical inputs). **Wall-clock time
  is directional only** — it mixes language runtime (PHP vs BEAM) with algorithmic work (robox does more search),
  so do not read it as a pure algorithm comparison.
- Two independent datasets (different seed + size range) to check the pattern isn't a fluke.
- Environment: PHP 8.5.8, Elixir 1.20.2 / OTP 29, Apple Silicon (Darwin). BoxPacker tag 4.2.0, robox `c159c72`.

## Results

### Dataset 1 (item dims 20–55)

| N  | BoxPacker fitted / util% / ms | robox fitted / util% / ms |
|----|-------------------------------|---------------------------|
| 5  | 5 / 43.8 / **3.1**            | 5 / 43.8 / 54             |
| 10 | 10 / 66.1 / **1.5**           | 10 / 66.1 / 91            |
| 20 | 11 / **80.7** / **19.7**      | **13** / 78.9 / 203       |
| 40 | 8 / **87.0** / **19.7**       | **14** / 78.4 / 317       |
| 80 | 8 / **91.2** / **35.9**       | **10** / 80.2 / 958       |

### Dataset 2 (item dims 15–60)

| N  | BoxPacker fitted / util% / ms | robox fitted / util% / ms |
|----|-------------------------------|---------------------------|
| 5  | 5 / 11.9 / **3.0**            | 5 / 11.9 / 69             |
| 10 | 10 / 27.7 / **3.5**           | 10 / 27.7 / 107           |
| 20 | 14 / **64.4** / **32.4**      | **17** / 62.3 / 258       |
| 40 | 8 / **87.0** / **11.0**       | **17** / 84.0 / 358       |
| 80 | 8 / **84.8** / **39.9**       | **16** / 80.7 / 832       |

(Bold = better on that metric.)

## Findings (consistent across both datasets)

1. **When everything fits (N = 5, 10):** identical utilisation — no quality difference; both find a full packing.
2. **Under overflow (N = 20, 40, 80) the two tools optimize different things:**
   - **robox fits more items** (e.g. 17 vs 8 at N = 40) — it packs many smaller pieces.
   - **BoxPacker achieves higher volume utilisation** — denser packing (e.g. 91.2 % vs 80.2 %), packing fewer,
     larger items tightly via largest-first layer building.
3. **Speed:** BoxPacker is roughly **5–30× faster in wall-clock** here and stays **< 40 ms** through N = 80; robox
   climbs to **~0.8–1.0 s** at N = 80 (branch-and-bound plus per-candidate extreme-point recomputation, and BEAM
   process startup dominates its tiny-N times).

## Verdict

- **Densest packing / highest volume utilisation → BoxPacker.** Note this **revised an earlier theoretical guess**
  that the extreme-point maximizer (robox) would pack denser; empirically, for cuboids-into-a-cube, BoxPacker's
  layer heuristic is denser.
- **Most pieces packed → robox.** Its ordering/entropy scoring favors item count over volume, despite its stated
  objective being volume.
- **Faster / more scalable → BoxPacker**, by a wide margin here (with the language caveat).

"Better" depends on the objective: **max volume utilisation (BoxPacker)** vs **max item count (robox)**.

## Caveats

- Single box shape (a cube) and moderate item-size ranges. Very flat, very irregular, or highly heterogeneous item
  mixes could shift the result.
- Wall-clock conflates language runtime and algorithm; it is not a pure algorithmic speed measurement.
- robox uses float geometry (with a 1e-8 tolerance) and quantizes weight at 0.25 in its ordering pre-pass;
  BoxPacker is integer-only. Neither affected these volume-only runs materially.
- One instance per (dataset, N). For publication-grade numbers, average over many seeds and box shapes.

## Takeaways for ex_box_packer

- Porting BoxPacker remains worthwhile: robox does **not** provide catalog-based multi-box selection, weight
  balancing, rotation-restriction modes (`:keep_flat` / `:never`), or placement constraints — all of which BoxPacker
  (and this port) provide.
- robox's extreme-point engine is a plausible **future alternative packing strategy** to offer alongside the
  BoxPacker-faithful layer packer, especially where maximizing item count matters more than density.

## Reproducing

Scripts live in [`scripts/`](./scripts). From a machine with PHP 8.2+, Composer, and Elixir/OTP (via `mise`):

```bash
# 1. Generate the shared dataset (dataset 1; use gen2.exs for dataset 2)
mise x erlang@29.0.3 elixir@1.20.2-otp-29 -- elixir docs/benchmarks/scripts/gen.exs   # writes /tmp/packbench/*.csv

# 2. BoxPacker (needs `composer install --no-dev` in the BoxPacker clone first)
php docs/benchmarks/scripts/bench_boxpacker.php

# 3. robox (run inside a robox checkout so the Robox module loads)
cd ~/Repos/robox && mise x erlang@29.0.3 elixir@1.20.2-otp-29 -- mix run <path>/bench_robox.exs
```

The scripts hard-code paths under `/tmp/packbench` and `~/Repos/BoxPacker`; adjust as needed.

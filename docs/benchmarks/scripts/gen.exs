# Deterministic shared dataset generator.
# Box: 100 x 100 x 100, max_weight huge (weight never binds).
# Items: integer dims in [20,55], weight = 1 each. Generate 80, nested by N.
:rand.seed(:exsss, {17, 42, 99})

box = {100, 100, 100, 100_000}
n_max = 80

items =
  for _ <- 1..n_max do
    d1 = 20 + :rand.uniform(36) - 1   # 20..55
    d2 = 20 + :rand.uniform(36) - 1
    d3 = 20 + :rand.uniform(36) - 1
    {d1, d2, d3, 1}
  end

File.write!("/tmp/packbench/box.csv", (box |> Tuple.to_list() |> Enum.join(",")) <> "\n")

rows =
  items
  |> Enum.map(fn {a, b, c, w} -> "#{a},#{b},#{c},#{w}" end)
  |> Enum.join("\n")

File.write!("/tmp/packbench/items_all.csv", rows <> "\n")

box_vol = 100 * 100 * 100
tot_vol = Enum.reduce(items, 0, fn {a, b, c, _}, acc -> acc + a * b * c end)
IO.puts("Wrote box.csv and items_all.csv (#{n_max} items)")
IO.puts("Box volume: #{box_vol}, total item volume (all 80): #{tot_vol} (#{Float.round(tot_vol / box_vol * 100, 1)}% of box)")

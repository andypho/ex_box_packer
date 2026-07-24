:rand.seed(:exsss, {7, 3, 1})
box = {100, 100, 100, 100_000}
items = for _ <- 1..80 do
  {15 + :rand.uniform(46) - 1, 15 + :rand.uniform(46) - 1, 15 + :rand.uniform(46) - 1, 1}
end
File.write!("/tmp/packbench/box.csv", (box |> Tuple.to_list() |> Enum.join(",")) <> "\n")
File.write!("/tmp/packbench/items_all.csv",
  (items |> Enum.map(fn {a,b,c,w} -> "#{a},#{b},#{c},#{w}" end) |> Enum.join("\n")) <> "\n")
tot = Enum.reduce(items, 0, fn {a,b,c,_}, acc -> acc + a*b*c end)
IO.puts("Dataset2: total item volume #{tot} (#{Float.round(tot/1_000_000*100,1)}% of box)")

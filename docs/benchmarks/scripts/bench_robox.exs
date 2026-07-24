# robox single-bin benchmark: reads the shared dataset, packs first N items
# into ONE box for several N, reports fitted count, utilisation, and time.

box_row =
  "/tmp/packbench/box.csv"
  |> File.read!()
  |> String.trim()
  |> String.split(",")
  |> Enum.map(&String.to_integer/1)

[bl, bd, bh, bmw] = box_row
box_vol = bl * bd * bh
bn = [bl, bd, bh, bmw]

all_items =
  "/tmp/packbench/items_all.csv"
  |> File.stream!()
  |> Enum.map(fn line ->
    line |> String.trim() |> String.split(",") |> Enum.map(&String.to_integer/1)
  end)
  |> Enum.reject(&(&1 == []))

ns = [5, 10, 20, 40, 80]

IO.puts(:io_lib.format("~-6s ~-8s ~-8s ~-14s ~-12s", ["N", "fitted", "unfit", "util(%)", "time(ms)"]))

Enum.each(ns, fn n ->
  ldhw = all_items |> Enum.take(n) |> Enum.map(fn [d1, d2, d3, wt] -> [d1, d2, d3, wt] end)

  {us, res} = :timer.tc(fn -> Robox.pack(ldhw, [bn], :gbp4d) end)

  fitted = Enum.count(res.k, &(&1 == 1))
  util = Float.round(res.o / box_vol * 100, 1)
  ms = Float.round(us / 1000, 2)

  IO.puts(
    :io_lib.format("~-6b ~-8b ~-8b ~-14ts ~-12ts", [
      n,
      fitted,
      n - fitted,
      :erlang.float_to_binary(util, decimals: 1),
      :erlang.float_to_binary(ms, decimals: 2)
    ])
  )
end)

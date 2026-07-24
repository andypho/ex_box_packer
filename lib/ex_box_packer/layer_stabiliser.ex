defmodule ExBoxPacker.LayerStabiliser do
  @moduledoc """
  Reorders packed layers so larger-footprint (then deeper) layers sit at the bottom, and
  recomputes each item's `z` so layers stack contiguously from `z = 0`. Port of
  BoxPacker's `LayerStabiliser`.
  """

  import ExBoxPacker.ItemSorter, only: [cmp: 2]
  alias ExBoxPacker.{PackedItem, PackedLayer}

  @spec stabilise([PackedLayer.t()]) :: [PackedLayer.t()]
  def stabilise(layers) do
    layers
    |> Enum.sort(&(compare(&1, &2) <= 0))
    |> restack(0, [])
  end

  defp compare(a, b) do
    case cmp(PackedLayer.footprint(b), PackedLayer.footprint(a)) do
      0 -> cmp(PackedLayer.depth(b), PackedLayer.depth(a))
      decider -> decider
    end
  end

  defp restack([], _current_z, acc), do: Enum.reverse(acc)

  defp restack([old_layer | rest], current_z, acc) do
    old_z_start = PackedLayer.start_z(old_layer)

    new_layer =
      Enum.reduce(PackedLayer.items(old_layer), PackedLayer.new(), fn item, layer ->
        new_z = item.z - old_z_start + current_z
        PackedLayer.insert(layer, PackedItem.new(item.item, item.x, item.y, new_z, item.width, item.length, item.depth))
      end)

    restack(rest, current_z + PackedLayer.depth(new_layer), [new_layer | acc])
  end
end

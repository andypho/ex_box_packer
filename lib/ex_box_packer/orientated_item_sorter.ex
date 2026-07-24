defmodule ExBoxPacker.OrientatedItemSorter do
  @moduledoc """
  Orders candidate orientations best-first. Port of BoxPacker's `OrientatedItemSorter`
  comparator, minus the look-ahead tiebreaker (added in Milestone 2b once `VolumePacker`
  exists). Priority: exact fit in width, then length, then depth; then smallest
  `min(width_left, length_left)` gap; then smallest surface footprint.

  Context is `%{width_left: integer, length_left: integer, depth_left: integer}`.
  """

  import ExBoxPacker.ItemSorter, only: [cmp: 2]
  alias ExBoxPacker.OrientatedItem

  @type ctx :: %{width_left: integer(), length_left: integer(), depth_left: integer()}

  @spec compare(OrientatedItem.t(), OrientatedItem.t(), ctx()) :: -1 | 0 | 1
  def compare(%OrientatedItem{} = a, %OrientatedItem{} = b, ctx) do
    %{width_left: wl, length_left: ll, depth_left: dl} = ctx

    with 0 <- exact_fit_decider(wl - a.width, wl - b.width),
         0 <- exact_fit_decider(ll - a.length, ll - b.length),
         0 <- exact_fit_decider(dl - a.depth, dl - b.depth) do
      a_min_gap = min(wl - a.width, ll - a.length)
      b_min_gap = min(wl - b.width, ll - b.length)

      case cmp(a_min_gap, b_min_gap) do
        0 -> cmp(a.surface_footprint, b.surface_footprint)
        gap_decider -> gap_decider
      end
    end
  end

  @doc "Sort orientations best-first using `compare/3` (stable)."
  @spec sort([OrientatedItem.t()], ctx()) :: [OrientatedItem.t()]
  def sort(orientations, ctx), do: Enum.sort(orientations, &(compare(&1, &2, ctx) <= 0))

  defp exact_fit_decider(a_left, b_left) do
    cond do
      a_left == 0 and b_left > 0 -> -1
      a_left > 0 and b_left == 0 -> 1
      true -> 0
    end
  end
end

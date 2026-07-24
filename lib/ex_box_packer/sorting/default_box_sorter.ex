defmodule ExBoxPacker.DefaultBoxSorter do
  @moduledoc "Default box ordering: inner volume asc, then empty weight asc, then usable capacity asc."
  @behaviour ExBoxPacker.BoxSorter

  import ExBoxPacker.ItemSorter, only: [cmp: 2]
  alias ExBoxPacker.Box

  @impl true
  def compare(a, b) do
    vol_a = Box.inner_width(a) * Box.inner_length(a) * Box.inner_depth(a)
    vol_b = Box.inner_width(b) * Box.inner_length(b) * Box.inner_depth(b)

    case cmp(vol_a, vol_b) do
      0 ->
        case cmp(Box.empty_weight(a), Box.empty_weight(b)) do
          0 ->
            cmp(
              Box.max_weight(a) - Box.empty_weight(a),
              Box.max_weight(b) - Box.empty_weight(b)
            )

          empty_weight_decider ->
            empty_weight_decider
        end

      volume_decider ->
        volume_decider
    end
  end
end

defmodule ExBoxPacker.DefaultPackedBoxSorter do
  @moduledoc "Default packed-box ordering: item count desc, then volume utilisation desc, then used volume desc."
  @behaviour ExBoxPacker.PackedBoxSorter

  import ExBoxPacker.ItemSorter, only: [cmp: 2]
  alias ExBoxPacker.{PackedBox, PackedItemList}

  @impl true
  def compare(a, b) do
    count_a = PackedItemList.count(a.items)
    count_b = PackedItemList.count(b.items)

    case cmp(count_b, count_a) do
      0 ->
        case cmp(PackedBox.volume_utilisation(b), PackedBox.volume_utilisation(a)) do
          0 -> cmp(PackedBox.used_volume(b), PackedBox.used_volume(a))
          util_decider -> util_decider
        end

      count_decider ->
        count_decider
    end
  end
end

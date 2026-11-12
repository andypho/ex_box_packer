defmodule ExBoxPacker.Test.THPackTestItem do
  @moduledoc false
  # Port of BoxPacker's tests/Test/THPackTestItem.php: a plain OR-library item (no placement
  # hook). Vertical restrictions that reduce to :keep_flat or unrestricted :best_fit are
  # expressed via dimensions + rotation only; see `ExBoxPacker.Test.THPack.new_item/7`.
  defstruct [:description, :width, :length, :depth, allowed_rotation: :best_fit]

  @type t :: %__MODULE__{
          description: String.t(),
          width: integer(),
          length: integer(),
          depth: integer(),
          allowed_rotation: ExBoxPacker.Rotation.t()
        }
end

defimpl ExBoxPacker.Item, for: ExBoxPacker.Test.THPackTestItem do
  def description(item), do: item.description
  def width(item), do: item.width
  def length(item), do: item.length
  def depth(item), do: item.depth
  def weight(_item), do: 0
  def allowed_rotation(item), do: item.allowed_rotation
end

defmodule ExBoxPacker.Test.THPackConstrainedTestItem do
  @moduledoc false
  # Port of BoxPacker's tests/Test/THPackConstrainedTestItem.php: an OR-library item where
  # exactly two (or zero) of the three edges may stand vertical, which :keep_flat / :best_fit
  # cannot express. Packed as :best_fit, with the ConstrainedPlacementItem hook enforcing the
  # per-edge flags.
  defstruct [
    :description,
    :width,
    :width_allowed_vertical,
    :length,
    :length_allowed_vertical,
    :depth,
    :depth_allowed_vertical
  ]

  @type t :: %__MODULE__{
          description: String.t(),
          width: integer(),
          width_allowed_vertical: boolean(),
          length: integer(),
          length_allowed_vertical: boolean(),
          depth: integer(),
          depth_allowed_vertical: boolean()
        }
end

defimpl ExBoxPacker.Item, for: ExBoxPacker.Test.THPackConstrainedTestItem do
  def description(item), do: item.description
  def width(item), do: item.width
  def length(item), do: item.length
  def depth(item), do: item.depth
  def weight(_item), do: 0
  def allowed_rotation(_item), do: :best_fit
end

defimpl ExBoxPacker.ConstrainedPlacementItem, for: ExBoxPacker.Test.THPackConstrainedTestItem do
  # The placed depth (what points up) must be an edge the dataset allows as vertical.
  def can_be_packed?(item, _packed_box, _x, _y, _z, _width, _length, depth) do
    (depth == item.width and item.width_allowed_vertical) or
      (depth == item.length and item.length_allowed_vertical) or
      (depth == item.depth and item.depth_allowed_vertical)
  end
end

defmodule ExBoxPacker.Test.THPack do
  @moduledoc false
  alias ExBoxPacker.Test.{THPackConstrainedTestItem, THPackTestItem}

  @doc """
  Port of PublishedTestCasesTest::createThpackItem: build a fixture item from OR-library
  dimensions + per-edge "may stand vertical" flags.

    * all three flags → free :best_fit
    * exactly one flag → :keep_flat with that edge stored as depth
    * two (or zero) flags → `THPackConstrainedTestItem` (:best_fit + placement hook)
  """
  @spec new_item(String.t(), integer(), boolean(), integer(), boolean(), integer(), boolean()) ::
          THPackTestItem.t() | THPackConstrainedTestItem.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def new_item(description, w, wv, l, lv, d, dv) do
    case {wv, lv, dv} do
      {true, true, true} -> plain(description, w, l, d, :best_fit)
      {false, false, true} -> plain(description, w, l, d, :keep_flat)
      {true, false, false} -> plain(description, l, d, w, :keep_flat)
      {false, true, false} -> plain(description, w, d, l, :keep_flat)
      _ -> constrained(description, w, wv, l, lv, d, dv)
    end
  end

  defp plain(description, w, l, d, rotation),
    do: %THPackTestItem{
      description: description,
      width: w,
      length: l,
      depth: d,
      allowed_rotation: rotation
    }

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defp constrained(description, w, wv, l, lv, d, dv) do
    %THPackConstrainedTestItem{
      description: description,
      width: w,
      width_allowed_vertical: wv,
      length: l,
      length_allowed_vertical: lv,
      depth: d,
      depth_allowed_vertical: dv
    }
  end
end

defmodule ExBoxPacker.Engine.ItemSpec do
  @moduledoc false
  # Flat, precomputed view of an `ExBoxPacker.Item` for the packing hot path.
  #
  # The engine reads `Item.width/1` and friends millions of times per pack; each call is a
  # protocol dispatch. Wrapping once per pack turns those into struct field reads.
  #
  # This struct deliberately does NOT implement the `ExBoxPacker.Item` protocol. If it did,
  # a missed call site would silently dispatch and reintroduce the cost this exists to remove;
  # unimplemented, a miss is an immediate crash the suite catches.

  alias ExBoxPacker.Item

  @enforce_keys [:item, :width, :length, :depth, :weight, :rotation, :volume, :sorted_dims]
  defstruct [:item, :width, :length, :depth, :weight, :rotation, :volume, :sorted_dims]

  @type t :: %__MODULE__{
          item: Item.t(),
          width: integer(),
          length: integer(),
          depth: integer(),
          weight: integer(),
          rotation: ExBoxPacker.Rotation.t(),
          volume: integer(),
          sorted_dims: [integer()]
        }

  @doc "Wrap a user item. Idempotent: an existing spec is returned unchanged."
  @spec wrap(Item.t() | t()) :: t()
  def wrap(%__MODULE__{} = spec), do: spec

  def wrap(item) do
    w = Item.width(item)
    l = Item.length(item)
    d = Item.depth(item)

    %__MODULE__{
      item: item,
      width: w,
      length: l,
      depth: d,
      weight: Item.weight(item),
      rotation: Item.allowed_rotation(item),
      volume: w * l * d,
      sorted_dims: Enum.sort([w, l, d])
    }
  end

  @doc "True if `term` is already a spec."
  @spec spec?(term()) :: boolean()
  def spec?(%__MODULE__{}), do: true
  def spec?(_), do: false

  @doc "The original user item. Passes a raw item through unchanged."
  @spec user_item(Item.t() | t()) :: Item.t()
  def user_item(%__MODULE__{item: item}), do: item
  def user_item(item), do: item
end

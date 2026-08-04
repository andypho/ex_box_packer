defmodule ExBoxPacker.Preview do
  @moduledoc """
  Opt-in capture hook for the `ExBoxPacker.PackerPreview` dev visualiser.

  Enable in dev config and add the collector to your supervision tree:

      # config/dev.exs
      config :ex_box_packer, ExBoxPacker.Preview, enabled: true

      # application.ex (dev only)
      children = [ExBoxPacker.Preview.Collector | rest]

  Then, after packing, capture the result:

      {:ok, result} = ExBoxPacker.Packer.pack(boxes, items)
      ExBoxPacker.Preview.capture(result, label: "order #123")

  When disabled (default) or the collector isn't running, `capture/2` is a cheap no-op.
  """

  alias ExBoxPacker.Packer
  alias ExBoxPacker.Preview.{Collector, Payload}
  alias ExBoxPacker.Result.PackedBoxList

  @doc "Capture a packing for the preview (no-op unless enabled and the collector is running)."
  @spec capture(PackedBoxList.t(), keyword()) :: :ok
  def capture(%PackedBoxList{} = result, opts \\ []) do
    if enabled?() and Process.whereis(Collector) != nil do
      Collector.capture(Payload.build(result), Payload.summary(result), opts)
    end

    :ok
  end

  @doc "Whether preview capture is enabled (config `:ex_box_packer, ExBoxPacker.Preview, enabled: true`; default false)."
  @spec enabled?() :: boolean()
  def enabled?, do: Application.get_env(:ex_box_packer, __MODULE__, [])[:enabled] == true

  @doc "Convenience: `Packer.pack/3` then `capture/2`. Returns the `pack/3` result."
  @spec pack([ExBoxPacker.Box.t()], [ExBoxPacker.Item.t()], keyword()) ::
          {:ok, PackedBoxList.t()} | {:error, Exception.t()}
  def pack(boxes, items, opts \\ []) do
    {label, pack_opts} = Keyword.pop(opts, :label)

    case Packer.pack(boxes, items, pack_opts) do
      {:ok, result} = ok ->
        capture(result, label: label)
        ok

      other ->
        other
    end
  end
end

defmodule ExBoxPacker.Config do
  @moduledoc """
  Single-key config reader. All library configuration lives under one key:

      config :ex_box_packer, ExBoxPacker,
        preview:   [enabled: true, max_packings: 50],
        broadcast: [endpoint: MyAppWeb.Endpoint, field: :box_packing_event]
  """

  @spec preview() :: keyword()
  def preview, do: all()[:preview] || []

  @spec broadcast() :: keyword() | nil
  def broadcast, do: all()[:broadcast]

  defp all, do: Application.get_env(:ex_box_packer, ExBoxPacker, [])
end

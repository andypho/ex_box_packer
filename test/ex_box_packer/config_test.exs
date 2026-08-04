defmodule ExBoxPacker.ConfigTest do
  use ExUnit.Case, async: false

  alias ExBoxPacker.Config

  setup do
    original = Application.get_env(:ex_box_packer, ExBoxPacker)
    on_exit(fn -> restore(original) end)
    :ok
  end

  defp restore(nil), do: Application.delete_env(:ex_box_packer, ExBoxPacker)
  defp restore(v), do: Application.put_env(:ex_box_packer, ExBoxPacker, v)

  test "preview/0 and broadcast/0 default to [] and nil when unset" do
    Application.delete_env(:ex_box_packer, ExBoxPacker)
    assert Config.preview() == []
    assert Config.broadcast() == nil
  end

  test "reads nested preview and broadcast sub-keywords" do
    Application.put_env(:ex_box_packer, ExBoxPacker,
      preview: [enabled: true, max_packings: 7],
      broadcast: [endpoint: MyEndpoint, field: :box_packing_event]
    )

    assert Config.preview()[:enabled] == true
    assert Config.preview()[:max_packings] == 7
    assert Config.broadcast()[:endpoint] == MyEndpoint
    assert Config.broadcast()[:field] == :box_packing_event
  end
end

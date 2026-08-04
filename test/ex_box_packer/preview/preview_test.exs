defmodule ExBoxPacker.PreviewTest do
  use ExUnit.Case, async: false
  alias ExBoxPacker.{Packer, Preview, SimpleBox, SimpleItem}
  alias ExBoxPacker.Preview.Collector

  defp box,
    do: %SimpleBox{
      reference: "B",
      outer_width: 10,
      outer_length: 10,
      outer_depth: 10,
      empty_weight: 0,
      inner_width: 10,
      inner_length: 10,
      inner_depth: 10,
      max_weight: 1000
    }

  defp item,
    do: %SimpleItem{
      description: "c",
      width: 5,
      length: 5,
      depth: 5,
      weight: 1,
      allowed_rotation: :best_fit
    }

  test "capture is a no-op when disabled (returns :ok, nothing stored)" do
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: false])
    start_supervised!(Collector)
    {:ok, pbl} = Packer.pack([box()], [item()])
    assert Preview.capture(pbl, label: "x") == :ok
    assert Collector.list() == []
  end

  test "capture stores when enabled and collector running" do
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: true])
    start_supervised!(Collector)
    {:ok, pbl} = Packer.pack([box()], [item()])
    assert Preview.capture(pbl, label: "y") == :ok
    # cast is async — wait for it to land
    Process.sleep(20)
    assert [%{label: "y"}] = Collector.list()
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: false])
  end

  test "capture is a no-op when enabled but collector not running" do
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: true])
    {:ok, pbl} = Packer.pack([box()], [item()])
    assert Preview.capture(pbl, label: "z") == :ok
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: false])
  end
end

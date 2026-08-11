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

  test "pack/3 packs, captures under the given label, and returns the pack result" do
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: true])
    start_supervised!(Collector)

    assert {:ok, %ExBoxPacker.Result.PackedBoxList{}} =
             Preview.pack([box()], [item()], label: "via pack/3")

    # capture/2 casts — wait for it to land
    Process.sleep(20)
    assert [%{label: "via pack/3"}] = Collector.list()
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: false])
  end

  test "pack/3 strips :label and forwards the remaining opts to Packer.pack/3" do
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: false])

    opts = [strict_ordering?: true, max_boxes_to_balance_weight: 1]

    assert Preview.pack([box()], [item()], [{:label, "l"} | opts]) ==
             Packer.pack([box()], [item()], opts)
  end

  test "pack/3 returns the error unchanged and captures nothing when packing fails" do
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: true])
    start_supervised!(Collector)

    oversized = %SimpleItem{
      description: "too big",
      width: 500,
      length: 500,
      depth: 500,
      weight: 1,
      allowed_rotation: :best_fit
    }

    assert {:error, %ExBoxPacker.NoBoxesAvailableError{}} = Preview.pack([box()], [oversized])

    Process.sleep(20)
    assert Collector.list() == []
    Application.put_env(:ex_box_packer, ExBoxPacker, preview: [enabled: false])
  end
end

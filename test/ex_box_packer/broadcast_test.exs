defmodule ExBoxPacker.BroadcastTest do
  use ExUnit.Case, async: false

  alias ExBoxPacker.Broadcast
  alias ExBoxPacker.Broadcast.Event
  alias ExBoxPacker.{SimpleBox, SimpleItem}

  setup do
    original = Application.get_env(:ex_box_packer, ExBoxPacker)

    on_exit(fn ->
      if original,
        do: Application.put_env(:ex_box_packer, ExBoxPacker, original),
        else: Application.delete_env(:ex_box_packer, ExBoxPacker)
    end)

    :ok
  end

  test "publish is a no-op when topic is nil" do
    Application.put_env(:ex_box_packer, ExBoxPacker, broadcast: [endpoint: NoSuch, field: :x])
    assert Broadcast.started(nil) == :ok
    assert Broadcast.box_packed(nil, :anything) == :ok
    assert Broadcast.done(nil, %{}) == :ok
  end

  test "publish is a no-op when broadcast is unconfigured" do
    Application.delete_env(:ex_box_packer, ExBoxPacker)
    assert Broadcast.started("box_packing:abc") == :ok
  end

  test "an injected :publisher receives (topic, event)" do
    test_pid = self()

    Application.put_env(:ex_box_packer, ExBoxPacker,
      broadcast: [publisher: fn topic, event -> send(test_pid, {:pub, topic, event}) end]
    )

    assert Broadcast.started("box_packing:xyz") == :ok
    assert_received {:pub, "box_packing:xyz", %Event{type: :started}}
  end

  test "summary/2 computes box_count, utilisation, and passes through leftovers" do
    box = %SimpleBox{
      reference: "b",
      outer_width: 100,
      outer_length: 100,
      outer_depth: 100,
      inner_width: 100,
      inner_length: 100,
      inner_depth: 100,
      empty_weight: 0,
      max_weight: 10_000
    }

    item = %SimpleItem{
      description: "i",
      width: 50,
      length: 50,
      depth: 50,
      weight: 10,
      allowed_rotation: :best_fit
    }

    {packed, leftover} = ExBoxPacker.Packer.pack_all_possible([box], [item])

    summary = Broadcast.summary(packed, leftover)
    assert summary.box_count == 1
    # 50×50×50 item (125 000) in a 100³ box (1 000 000) → 12.5% utilisation.
    assert summary.volume_utilisation == 12.5
    assert summary.unpacked == []
  end
end

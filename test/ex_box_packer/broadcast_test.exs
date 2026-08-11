defmodule ExBoxPacker.BroadcastTest do
  use ExUnit.Case, async: false

  alias ExBoxPacker.Broadcast
  alias ExBoxPacker.Broadcast.Event
  alias ExBoxPacker.{SimpleBox, SimpleItem}
  alias ExBoxPacker.Test.TestPubsub

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

  describe "the Absinthe publish path" do
    test "publishes through Absinthe.Subscription with the configured endpoint, field and topic" do
      start_supervised!({Absinthe.Subscription, pubsub: TestPubsub})
      TestPubsub.set_owner(self())

      Application.put_env(:ex_box_packer, ExBoxPacker,
        broadcast: [endpoint: TestPubsub, field: :box_packing]
      )

      assert Broadcast.started("box_packing:abc") == :ok

      assert_receive {:absinthe_mutation, _proxy_topic, %Event{type: :started},
                      [{:box_packing, "box_packing:abc"}]}
    end

    test "publishes each event type" do
      start_supervised!({Absinthe.Subscription, pubsub: TestPubsub})
      TestPubsub.set_owner(self())

      Application.put_env(:ex_box_packer, ExBoxPacker,
        broadcast: [endpoint: TestPubsub, field: :box_packing]
      )

      assert Broadcast.box_packed("t", :a_box) == :ok
      assert_receive {:absinthe_mutation, _, %Event{type: :box_packed, box: :a_box}, _}

      assert Broadcast.done("t", %{box_count: 1}) == :ok
      assert_receive {:absinthe_mutation, _, %Event{type: :done, summary: %{box_count: 1}}, _}
    end

    test "an injected :publisher takes precedence over the Absinthe path" do
      start_supervised!({Absinthe.Subscription, pubsub: TestPubsub})
      TestPubsub.set_owner(self())
      test_pid = self()

      Application.put_env(:ex_box_packer, ExBoxPacker,
        broadcast: [
          endpoint: TestPubsub,
          field: :box_packing,
          publisher: fn topic, event -> send(test_pid, {:pub, topic, event}) end
        ]
      )

      assert Broadcast.started("t") == :ok
      assert_received {:pub, "t", %Event{type: :started}}
      refute_received {:absinthe_mutation, _, _, _}
    end

    test "is a no-op when :endpoint is configured but :field is missing" do
      Application.put_env(:ex_box_packer, ExBoxPacker, broadcast: [endpoint: TestPubsub])
      assert Broadcast.started("t") == :ok
    end

    test "is a no-op when :field is configured but :endpoint is missing" do
      Application.put_env(:ex_box_packer, ExBoxPacker, broadcast: [field: :box_packing])
      assert Broadcast.started("t") == :ok
    end
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

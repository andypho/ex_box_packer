defmodule ExBoxPacker.Preview.CollectorTest do
  use ExUnit.Case, async: false
  alias ExBoxPacker.Preview.Collector

  defp payload(tag), do: %{"items" => [[tag, 1, 1, 1]], "boxes" => []}
  defp summary, do: %{boxes: 1, items: 1, utilisation: 1.0}

  setup do
    start_supervised!({Collector, [max_packings: 3]})
    :ok
  end

  test "capture stores packings, list is newest-first, get returns payload" do
    Collector.capture(payload("a"), summary(), label: "a")
    Collector.capture(payload("b"), summary(), label: "b")
    list = Collector.list()
    assert [%{label: "b", id: id_b}, %{label: "a"}] = list
    assert %{"items" => [["b", 1, 1, 1]], "boxes" => []} = Collector.get(id_b)
    assert Collector.get(-1) == nil
  end

  test "ring buffer evicts oldest beyond max_packings" do
    for t <- ["a", "b", "c", "d"], do: Collector.capture(payload(t), summary(), label: t)
    labels = Collector.list() |> Enum.map(& &1.label)
    assert labels == ["d", "c", "b"]
  end

  test "subscribers are notified of new packings and cleaned up when down" do
    Collector.subscribe()
    Collector.capture(payload("x"), summary(), label: "x")
    assert_receive {:preview_packing, %{label: "x"}}
  end

  test "a subscriber that dies is dropped from the subscriber set" do
    test_pid = self()

    sub =
      spawn(fn ->
        Collector.subscribe()
        send(test_pid, :subscribed)
        Process.sleep(:infinity)
      end)

    assert_receive :subscribed

    ref = Process.monitor(sub)
    Process.exit(sub, :kill)
    assert_receive {:DOWN, ^ref, :process, ^sub, :killed}

    # Capturing after the subscriber is gone must not raise, and the collector
    # must have processed the :DOWN and removed it. A synchronous call afterwards
    # proves the collector handled :DOWN without crashing.
    Collector.capture(payload("y"), summary(), label: "y")
    assert [%{label: "y"}] = Collector.list()
    assert :sys.get_state(Collector).subscribers == MapSet.new()
  end

  test "capture and capture_sync accept a bare payload and summary with no opts" do
    Collector.capture(payload("no-opts"), summary())
    assert [%{label: nil}] = Collector.list()

    id = Collector.capture_sync(payload("no-opts-sync"), summary())
    assert is_integer(id)
    assert [%{label: nil, id: ^id}, %{label: nil}] = Collector.list()
  end

  test "capture_sync stores and returns the assigned id" do
    id = Collector.capture_sync(payload("s"), summary(), label: "s")
    assert is_integer(id)
    assert %{"items" => [["s", 1, 1, 1]], "boxes" => []} = Collector.get(id)
    assert [%{label: "s", id: ^id}] = Collector.list()
  end
end

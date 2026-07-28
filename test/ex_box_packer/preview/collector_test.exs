defmodule ExBoxPacker.Preview.CollectorTest do
  use ExUnit.Case, async: false
  alias ExBoxPacker.Preview.Collector

  defp payload(tag), do: %{"items" => [[tag, 1, 1, 1]], "boxes" => []}
  defp summary(), do: %{boxes: 1, items: 1, utilisation: 1.0}

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
end

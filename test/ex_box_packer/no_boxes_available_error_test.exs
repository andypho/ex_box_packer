defmodule ExBoxPacker.NoBoxesAvailableErrorTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.{NoBoxesAvailableError, SimpleItem}

  test "exception/1 builds a message from the first affected item and keeps the list" do
    items = [
      %SimpleItem{description: "widget", width: 1, length: 1, depth: 1, weight: 1},
      %SimpleItem{description: "gadget", width: 2, length: 2, depth: 2, weight: 1}
    ]

    err = NoBoxesAvailableError.exception(items)
    assert err.message =~ "widget"
    assert err.affected_items == items
  end

  test "it is raisable" do
    assert_raise NoBoxesAvailableError, fn ->
      raise NoBoxesAvailableError.exception([%SimpleItem{description: "x", width: 1, length: 1, depth: 1, weight: 1}])
    end
  end
end

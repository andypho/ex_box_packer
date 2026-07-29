defmodule ExBoxPacker.Preview.SpecTest do
  use ExUnit.Case, async: true
  alias ExBoxPacker.Preview.Spec
  alias ExBoxPacker.{SimpleBox, SimpleItem}

  defp req(overrides \\ %{}) do
    Map.merge(
      %{
        "boxes" => [
          %{"reference" => "AusPost Medium", "width" => 310, "length" => 225, "depth" => 102, "max_weight" => 22_000}
        ],
        "items" => [
          %{"description" => "widget", "width" => 100, "length" => 80, "depth" => 60, "weight" => 500, "quantity" => 4, "rotation" => "best_fit"}
        ]
      },
      overrides
    )
  end

  test "decodes a valid request into SimpleBox/SimpleItem structs" do
    assert {:ok, {[box], [item]}} = Spec.decode(req())

    assert %SimpleBox{
             reference: "AusPost Medium",
             outer_width: 310,
             inner_width: 310,
             inner_length: 225,
             inner_depth: 102,
             empty_weight: 0,
             max_weight: 22_000
           } = box

    assert %SimpleItem{
             description: "widget",
             width: 100,
             length: 80,
             depth: 60,
             weight: 500,
             quantity: 4,
             allowed_rotation: :best_fit
           } = item
  end

  test "empty boxes -> error" do
    assert {:error, msg} = Spec.decode(req(%{"boxes" => []}))
    assert msg =~ "at least one box"
  end

  test "empty items -> error" do
    assert {:error, msg} = Spec.decode(req(%{"items" => []}))
    assert msg =~ "at least one item"
  end

  test "non-positive dimension -> error" do
    boxes = [%{"reference" => "B", "width" => 0, "length" => 10, "depth" => 10}]
    assert {:error, msg} = Spec.decode(req(%{"boxes" => boxes}))
    assert msg =~ "positive whole number"
  end

  test "invalid rotation -> error" do
    items = [%{"description" => "x", "width" => 1, "length" => 1, "depth" => 1, "weight" => 1, "rotation" => "sideways"}]
    assert {:error, msg} = Spec.decode(req(%{"items" => items}))
    assert msg =~ "invalid rotation"
  end

  test "box over AusPost length limit -> error" do
    boxes = [%{"reference" => "Long", "width" => 1200, "length" => 100, "depth" => 100}]
    assert {:error, msg} = Spec.decode(req(%{"boxes" => boxes}))
    assert msg =~ "longest side 1200 mm > 1050 mm"
  end

  test "box over AusPost volume limit -> error" do
    # 1000 x 700 x 400 = 280,000,000 mm³ (> 250,000,000); longest side 1000 <= 1050
    boxes = [%{"reference" => "Big", "width" => 1000, "length" => 700, "depth" => 400}]
    assert {:error, msg} = Spec.decode(req(%{"boxes" => boxes}))
    assert msg =~ "volume 280000000 mm³ > 250000000"
  end

  test "box over AusPost weight limit -> error" do
    boxes = [%{"reference" => "Heavy", "width" => 100, "length" => 100, "depth" => 100, "max_weight" => 30_000}]
    assert {:error, msg} = Spec.decode(req(%{"boxes" => boxes}))
    assert msg =~ "max weight 30000 g > 22000 g"
  end

  test "max_weight defaults to 22000 and quantity/rotation default when omitted" do
    boxes = [%{"reference" => "B", "width" => 100, "length" => 100, "depth" => 100}]
    items = [%{"description" => "x", "width" => 10, "length" => 10, "depth" => 10, "weight" => 5}]
    assert {:ok, {[box], [item]}} = Spec.decode(req(%{"boxes" => boxes, "items" => items}))
    assert box.max_weight == 22_000
    assert item.quantity == 1
    assert item.allowed_rotation == :best_fit
  end

  test "non-map input -> error" do
    assert {:error, msg} = Spec.decode([])
    assert msg =~ "expected a JSON object"
  end

  test "integer-string dimensions are coerced" do
    boxes = [%{"reference" => "B", "width" => "310", "length" => "225", "depth" => "102"}]
    assert {:ok, {[box], _}} = Spec.decode(req(%{"boxes" => boxes}))
    assert box.inner_width == 310
    assert box.inner_length == 225
    assert box.inner_depth == 102
  end

  test "empty-string quantity falls back to the default" do
    items = [%{"description" => "x", "width" => 10, "length" => 10, "depth" => 10, "weight" => 5, "quantity" => ""}]
    assert {:ok, {_, [item]}} = Spec.decode(req(%{"items" => items}))
    assert item.quantity == 1
  end

  test "non-map box entry -> error" do
    assert {:error, msg} = Spec.decode(req(%{"boxes" => ["not a map"]}))
    assert msg =~ "box 1 must be an object"
  end
end

defmodule ExBoxPacker.Preview.SpecTest do
  use ExUnit.Case, async: true

  alias ExBoxPacker.Preview.Spec
  alias ExBoxPacker.{SimpleBox, SimpleItem}

  defp box_map(extra \\ %{}),
    do: Map.merge(%{"reference" => "B", "width" => 100, "length" => 100, "depth" => 100}, extra)

  defp item_map(extra \\ %{}),
    do:
      Map.merge(
        %{"description" => "i", "width" => 10, "length" => 10, "depth" => 10, "weight" => 5},
        extra
      )

  defp decode(boxes, items), do: Spec.decode(%{"boxes" => boxes, "items" => items})

  test "decodes a minimal valid spec into SimpleBox/SimpleItem structs" do
    assert {:ok, {[%SimpleBox{reference: "B"}], [%SimpleItem{description: "i"}]}} =
             decode([box_map()], [item_map()])
  end

  test "decodes a valid request into fully populated SimpleBox/SimpleItem structs" do
    boxes = [
      %{
        "reference" => "AusPost Medium",
        "width" => 310,
        "length" => 225,
        "depth" => 102,
        "max_weight" => 22_000
      }
    ]

    items = [
      %{
        "description" => "widget",
        "width" => 100,
        "length" => 80,
        "depth" => 60,
        "weight" => 500,
        "quantity" => 4,
        "rotation" => "best_fit"
      }
    ]

    assert {:ok, {[box], [item]}} = decode(boxes, items)

    # A box's inner dimensions mirror its outer ones (the sandbox has no wall thickness).
    assert %SimpleBox{
             reference: "AusPost Medium",
             outer_width: 310,
             outer_length: 225,
             outer_depth: 102,
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

  test "a reference or description falls back to a positional default when absent" do
    assert {:ok, {[%SimpleBox{reference: "Box 1"}], [%SimpleItem{description: "item 1"}]}} =
             decode([Map.delete(box_map(), "reference")], [Map.delete(item_map(), "description")])
  end

  test "input that is not a map is rejected" do
    assert {:error, msg} = Spec.decode([])
    assert msg =~ "expected a JSON object"

    assert {:error, "invalid request: expected a JSON object"} = Spec.decode("nope")
    assert {:error, "invalid request: expected a JSON object"} = Spec.decode(nil)
  end

  describe "fetch_list/2" do
    test "a non-list value for boxes or items is rejected" do
      assert decode("nope", [item_map()]) == {:error, "boxes must be a non-empty list"}
      assert decode([box_map()], %{"a" => 1}) == {:error, "items must be a non-empty list"}
    end

    test "an absent boxes or items key is rejected" do
      assert Spec.decode(%{"items" => [item_map()]}) ==
               {:error, "boxes must be a non-empty list"}

      assert Spec.decode(%{"boxes" => [box_map()]}) ==
               {:error, "items must be a non-empty list"}
    end

    test "an empty list reports the singular 'at least one' message" do
      assert decode([], [item_map()]) == {:error, "at least one box is required"}
      assert decode([box_map()], []) == {:error, "at least one item is required"}
    end
  end

  describe "element type validation" do
    test "a non-object item is rejected with its 1-based index" do
      assert decode([box_map()], ["not an object"]) == {:error, "item 1 must be an object"}
      assert decode([box_map()], [item_map(), 42]) == {:error, "item 2 must be an object"}
    end

    test "a non-object box is rejected with its 1-based index" do
      assert decode(["not an object"], [item_map()]) == {:error, "box 1 must be an object"}
    end
  end

  describe "coerce/4" do
    test "a value of an uncoercible type is rejected" do
      assert decode([box_map()], [item_map(%{"width" => true})]) ==
               {:error, ~s(item "i": width must be a positive whole number)}

      assert decode([box_map()], [item_map(%{"width" => [10]})]) ==
               {:error, ~s(item "i": width must be a positive whole number)}
    end

    test "a missing required dimension is rejected" do
      assert decode([box_map()], [Map.delete(item_map(), "width")]) ==
               {:error, ~s(item "i": width must be a positive whole number)}
    end

    test "a non-integral float is rejected but an integral float is accepted" do
      assert decode([box_map()], [item_map(%{"width" => 10.5})]) ==
               {:error, ~s(item "i": width must be a positive whole number)}

      assert {:ok, {_, [%SimpleItem{width: 10}]}} =
               decode([box_map()], [item_map(%{"width" => 10.0})])
    end

    test "a non-positive value is rejected" do
      assert decode([box_map()], [item_map(%{"width" => 0})]) ==
               {:error, ~s(item "i": width must be a positive whole number)}

      assert decode([box_map()], [item_map(%{"width" => -5})]) ==
               {:error, ~s(item "i": width must be a positive whole number)}
    end
  end

  describe "parse_binary/1" do
    test "a numeric string is accepted, with surrounding whitespace trimmed" do
      assert {:ok, {_, [%SimpleItem{width: 25}]}} =
               decode([box_map()], [item_map(%{"width" => " 25 "})])
    end

    test "a non-numeric string is rejected" do
      assert decode([box_map()], [item_map(%{"width" => "abc"})]) ==
               {:error, ~s(item "i": width must be a positive whole number)}
    end

    test "a string with trailing non-numeric characters is rejected" do
      assert decode([box_map()], [item_map(%{"width" => "12abc"})]) ==
               {:error, ~s(item "i": width must be a positive whole number)}
    end
  end

  describe "Australia Post limits" do
    test "a box whose longest side exceeds the limit is rejected" do
      assert {:error, msg} =
               decode([box_map(%{"width" => 1200, "length" => 100, "depth" => 100})], [item_map()])

      assert msg == ~s(box "B" exceeds Australia Post limit: longest side 1200 mm > 1050 mm)
    end

    test "a box within the side limit but over the volume limit is rejected" do
      # 1000 mm sides are under the 1050 mm side limit, but 1 m³ > 0.25 m³.
      assert {:error, msg} =
               decode(
                 [box_map(%{"width" => 1000, "length" => 1000, "depth" => 1000})],
                 [item_map()]
               )

      assert msg ==
               ~s[box "B" exceeds Australia Post limit: volume 1000000000 mm³ > 250000000 mm³ (0.25 m³)]
    end

    test "a box over the max weight limit is rejected" do
      assert {:error, msg} = decode([box_map(%{"max_weight" => 30_000})], [item_map()])

      assert msg ==
               ~s[box "B" exceeds Australia Post limit: max weight 30000 g > 22000 g (22 kg)]
    end

    test "a box exactly on every limit is accepted" do
      assert {:ok, {[%SimpleBox{max_weight: 22_000}], _}} =
               decode(
                 [
                   box_map(%{
                     "width" => 1050,
                     "length" => 488,
                     "depth" => 487,
                     "max_weight" => 22_000
                   })
                 ],
                 [item_map()]
               )
    end
  end

  describe "rotation/2" do
    test "each rotation mode is accepted by name" do
      for mode <- ExBoxPacker.Rotation.values() do
        assert {:ok, {_, [%SimpleItem{allowed_rotation: ^mode}]}} =
                 decode([box_map()], [item_map(%{"rotation" => to_string(mode)})])
      end
    end

    test "an unknown rotation mode is rejected" do
      assert decode([box_map()], [item_map(%{"rotation" => "sideways"})]) ==
               {:error,
                ~s(item "i" has invalid rotation "sideways"; expected never, keep_flat, or best_fit)}
    end

    test "rotation defaults to best_fit when absent" do
      assert {:ok, {_, [%SimpleItem{allowed_rotation: :best_fit}]}} =
               decode([box_map()], [item_map()])
    end
  end

  describe "optional fields with defaults" do
    test "an empty string falls back to the default" do
      assert {:ok, {_, [%SimpleItem{quantity: 1}]}} =
               decode([box_map()], [item_map(%{"quantity" => ""})])

      assert {:ok, {[%SimpleBox{max_weight: 22_000}], _}} =
               decode([box_map(%{"max_weight" => ""})], [item_map()])
    end

    test "an invalid optional value is still rejected" do
      assert decode([box_map()], [item_map(%{"quantity" => "many"})]) ==
               {:error, ~s(item "i": quantity must be a positive whole number)}
    end
  end
end

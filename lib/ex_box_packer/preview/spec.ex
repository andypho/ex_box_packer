defmodule ExBoxPacker.Preview.Spec do
  @moduledoc false
  # Decodes a sandbox pack request (a parsed JSON map with string keys) into
  # {boxes, items} of SimpleBox/SimpleItem structs, or {:error, message}.
  # Every box is validated against Australia Post "Within Australia" parcel limits.

  alias ExBoxPacker.{Rotation, SimpleBox, SimpleItem}

  # Australia Post "Within Australia" parcel limits, in the sandbox's units (mm / mm³ / grams).
  # These are the three limits from the AusPost size guide (max longest side, max volume, max
  # weight). The separate length+girth rule is intentionally not enforced here.
  @max_length_mm 1_050
  @max_volume_mm3 250_000_000
  @max_weight_g 22_000

  # Derived from Rotation.values/0 so new rotation modes are accepted automatically.
  @rotations Map.new(Rotation.values(), &{to_string(&1), &1})

  @spec decode(term()) :: {:ok, {[SimpleBox.t()], [SimpleItem.t()]}} | {:error, String.t()}
  def decode(params) when is_map(params) do
    with {:ok, box_maps} <- fetch_list(params, "boxes"),
         {:ok, item_maps} <- fetch_list(params, "items"),
         {:ok, boxes} <- map_ok(box_maps, &decode_box/1),
         {:ok, items} <- map_ok(item_maps, &decode_item/1) do
      {:ok, {boxes, items}}
    end
  end

  def decode(_), do: {:error, "invalid request: expected a JSON object"}

  defp fetch_list(params, key) do
    case Map.get(params, key) do
      [_ | _] = list -> {:ok, list}
      [] -> {:error, "at least one #{singular(key)} is required"}
      _ -> {:error, "#{key} must be a non-empty list"}
    end
  end

  defp singular("boxes"), do: "box"
  defp singular("items"), do: "item"

  # Applies `fun` to each element with its 1-based index, collecting into a list or
  # short-circuiting on the first {:error, _}.
  defp map_ok(list, fun) do
    list
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {el, i}, {:ok, acc} ->
      case fun.({el, i}) do
        {:ok, v} -> {:cont, {:ok, [v | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      err -> err
    end
  end

  defp decode_box({m, i}) when is_map(m) do
    ref = to_string(Map.get(m, "reference") || "Box #{i}")

    with {:ok, w} <- pos_int(m, "width", ref, "box"),
         {:ok, l} <- pos_int(m, "length", ref, "box"),
         {:ok, d} <- pos_int(m, "depth", ref, "box"),
         {:ok, mw} <- pos_int_default(m, "max_weight", @max_weight_g, ref, "box"),
         :ok <- check_auspost(ref, w, l, d, mw) do
      {:ok,
       %SimpleBox{
         reference: ref,
         outer_width: w,
         outer_length: l,
         outer_depth: d,
         inner_width: w,
         inner_length: l,
         inner_depth: d,
         empty_weight: 0,
         max_weight: mw
       }}
    end
  end

  defp decode_box({_, i}), do: {:error, "box #{i} must be an object"}

  defp decode_item({m, i}) when is_map(m) do
    desc = to_string(Map.get(m, "description") || "item #{i}")

    with {:ok, w} <- pos_int(m, "width", desc, "item"),
         {:ok, l} <- pos_int(m, "length", desc, "item"),
         {:ok, d} <- pos_int(m, "depth", desc, "item"),
         {:ok, wt} <- pos_int(m, "weight", desc, "item"),
         {:ok, qty} <- pos_int_default(m, "quantity", 1, desc, "item"),
         {:ok, rot} <- rotation(m, desc) do
      {:ok,
       %SimpleItem{
         description: desc,
         width: w,
         length: l,
         depth: d,
         weight: wt,
         quantity: qty,
         allowed_rotation: rot
       }}
    end
  end

  defp decode_item({_, i}), do: {:error, "item #{i} must be an object"}

  defp check_auspost(ref, w, l, d, mw) do
    longest = Enum.max([w, l, d])
    volume = w * l * d

    cond do
      longest > @max_length_mm ->
        {:error, ~s(box "#{ref}" exceeds Australia Post limit: longest side #{longest} mm > #{@max_length_mm} mm)}

      volume > @max_volume_mm3 ->
        {:error, ~s[box "#{ref}" exceeds Australia Post limit: volume #{volume} mm³ > #{@max_volume_mm3} mm³ (0.25 m³)]}

      mw > @max_weight_g ->
        {:error, ~s[box "#{ref}" exceeds Australia Post limit: max weight #{mw} g > #{@max_weight_g} g (22 kg)]}

      true ->
        :ok
    end
  end

  defp rotation(m, desc) do
    key = to_string(Map.get(m, "rotation", "best_fit"))

    case Map.fetch(@rotations, key) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:error, ~s(item "#{desc}" has invalid rotation "#{key}"; expected never, keep_flat, or best_fit)}
    end
  end

  defp pos_int(m, key, name, kind), do: coerce(Map.get(m, key), key, name, kind)

  defp pos_int_default(m, key, default, name, kind) do
    case Map.get(m, key) do
      nil -> {:ok, default}
      "" -> {:ok, default}
      val -> coerce(val, key, name, kind)
    end
  end

  defp coerce(val, key, name, kind) do
    int =
      cond do
        is_integer(val) -> val
        is_float(val) and trunc(val) == val -> trunc(val)
        is_binary(val) -> parse_binary(val)
        true -> :error
      end

    case int do
      n when is_integer(n) and n > 0 -> {:ok, n}
      _ -> {:error, ~s(#{kind} "#{name}": #{key} must be a positive whole number)}
    end
  end

  defp parse_binary(s) do
    case Integer.parse(String.trim(s)) do
      {n, ""} -> n
      _ -> :error
    end
  end
end

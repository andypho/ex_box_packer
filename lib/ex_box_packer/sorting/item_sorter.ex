defmodule ExBoxPacker.Sorting.ItemSorter do
  @moduledoc "Behaviour for ordering items before packing (analog of BoxPacker's `ItemSorter`)."

  @doc "Return a negative int if `a` sorts before `b`, positive if after, 0 if equal."
  @callback compare(a :: ExBoxPacker.Item.t(), b :: ExBoxPacker.Item.t()) :: integer()

  @doc "Compare two terms and return -1, 0, or 1 (PHP spaceship semantics)."
  @spec cmp(term(), term()) :: -1 | 0 | 1
  def cmp(a, b) when a < b, do: -1
  def cmp(a, b) when a > b, do: 1
  def cmp(_, _), do: 0

  @doc """
  Compare two strings the way PHP 8's `<=>` does: numerically when both are numeric strings
  (`"9" < "10"`, `"1e3" == "1000"`), byte-wise otherwise. `nil` compares as `""`, the way PHP
  coerces `null`.
  """
  @spec string_cmp(String.t() | nil, String.t() | nil) :: -1 | 0 | 1
  def string_cmp(a, b) do
    a = a || ""
    b = b || ""

    with {:ok, num_a} <- php_number(a),
         {:ok, num_b} <- php_number(b) do
      cmp(num_a, num_b)
    else
      :error -> cmp(a, b)
    end
  end

  @php_whitespace [?\s, ?\t, ?\n, ?\r, ?\v, ?\f]

  # PHP's numeric-string grammar: optional surrounding whitespace, an optional sign, then an
  # integer ("7"), a decimal ("7.5", ".5", "5.") or either with an exponent ("1e3"). Anything
  # else ("10a", "0x1A", "1_000", "") is not numeric.
  defp php_number(str) do
    {sign, rest} = str |> skip_whitespace() |> take_sign()
    {int, rest} = take_digits(rest, "")
    {frac, rest} = take_fraction(rest)
    {exp, rest} = take_exponent(rest)

    if (int != "" or (frac != nil and frac != "")) and skip_whitespace(rest) == "",
      do: to_number(sign, int, frac, exp),
      else: :error
  end

  defp skip_whitespace(<<c, rest::binary>>) when c in @php_whitespace, do: skip_whitespace(rest)
  defp skip_whitespace(rest), do: rest

  defp take_sign(<<s, rest::binary>>) when s in [?+, ?-], do: {<<s>>, rest}
  defp take_sign(rest), do: {"", rest}

  defp take_digits(<<d, rest::binary>>, acc) when d in ?0..?9,
    do: take_digits(rest, <<acc::binary, d>>)

  defp take_digits(rest, acc), do: {acc, rest}

  defp take_fraction(<<?., rest::binary>>), do: take_digits(rest, "")
  defp take_fraction(rest), do: {nil, rest}

  # An exponent marker without digits ("1e") is not consumed, so it fails the trailing check.
  defp take_exponent(<<e, rest::binary>> = str) when e in [?e, ?E] do
    {sign, after_sign} = take_sign(rest)

    case take_digits(after_sign, "") do
      {"", _} -> {nil, str}
      {digits, rest} -> {sign <> digits, rest}
    end
  end

  defp take_exponent(rest), do: {nil, rest}

  defp to_number(sign, int, nil, nil), do: {:ok, String.to_integer(sign <> int)}

  defp to_number(sign, int, frac, exp) do
    mantissa = "#{sign}#{zero_if_empty(int)}.#{zero_if_empty(frac || "")}"

    case Float.parse("#{mantissa}e#{exp || "0"}") do
      {float, ""} -> {:ok, float}
      _ -> :error
    end
  end

  defp zero_if_empty(""), do: "0"
  defp zero_if_empty(digits), do: digits
end

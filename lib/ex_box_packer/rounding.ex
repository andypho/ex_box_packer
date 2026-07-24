defmodule ExBoxPacker.Rounding do
  @moduledoc """
  PHP-compatible rounding.

  PHP's `round($x, $p)` rounds half **away from zero** and compensates for
  floating-point representation error ("pre-rounding"). Elixir's `Float.round/2`
  rounds the stored IEEE-754 value and can differ at `.x5` boundaries (e.g. `0.15`
  rounds to `0.1` in Elixir but `0.2` in PHP). This module reproduces PHP's result
  so utilisation/variance values match the reference implementation for golden
  fidelity.
  """

  @doc "Round `value` to `precision` decimal places, half away from zero (PHP `round/2`)."
  @spec round_half_up(number(), non_neg_integer()) :: float()
  def round_half_up(value, precision \\ 0) do
    factor = :math.pow(10, precision)
    # Strip binary representation error at the scaled magnitude before deciding half-up.
    scaled = Float.round(value * factor, 9)

    rounded =
      if scaled >= 0.0 do
        Float.floor(scaled + 0.5)
      else
        Float.ceil(scaled - 0.5)
      end

    rounded / factor
  end
end

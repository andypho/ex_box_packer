defmodule ExBoxPacker.Rounding do
  @moduledoc false

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

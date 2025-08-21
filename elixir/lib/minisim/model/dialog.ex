defmodule MiniSim.Model.Dialog do
  alias MiniSim.Model.TransitionMatrix

  @doc """
  Simulates communication between two agents and returns updated preferences.
  Returns {alice_prefs, bob_prefs}.
  """
  def talk(alice, bob) do
    joint = for a <- alice.preferences, b <- bob.preferences, do: a * b
    # Build 9x9 transition matrix
    t = TransitionMatrix.build(alice, bob)
    # r = v @ T (length 9)
    r =
      for j <- 0..8 do
        Enum.reduce(0..8, 0.0, fn k, acc -> acc + Enum.at(joint, k) * Enum.at(Enum.at(t, k), j) end)
      end

    # reshape to 3x3
    result = for i <- 0..2 do Enum.slice(r, i * 3, 3) end

    alice_result = Enum.map(0..2, fn i -> result |> Enum.at(i) |> Enum.sum() |> round_safely() end)
    bob_result =
      Enum.map(0..2, fn j ->
        Enum.reduce(0..2, 0.0, fn i, acc ->
          acc + (result |> Enum.at(i) |> Enum.at(j))
        end)
        |> round_safely()
      end)

    alice_sum = Enum.sum(alice_result)
    bob_sum = Enum.sum(bob_result)

    alice_prefs = Enum.map(alice_result, &(&1 / alice_sum))
    bob_prefs = Enum.map(bob_result, &(&1 / bob_sum))

    {alice_prefs, bob_prefs}
  end

  defp round_safely(value) when is_float(value), do: Float.round(value, 3)
  defp round_safely(value) when is_integer(value), do: Float.round(value * 1.0, 3)
  defp round_safely(value), do: Float.round(value * 1.0, 3)
end

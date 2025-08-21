defmodule MiniSim.Model.Dialog do
  alias MiniSim.Model.TransitionMatrix

  @doc """
  Simulates communication between two agents and returns updated preferences.
  Returns {alice_prefs, bob_prefs}.
  """
  def talk(alice, bob) do
    joint_prefs = joint_preference(alice.preferences, bob.preferences)

    transition_matrix = TransitionMatrix.build(alice, bob)
    transition_tensor = Nx.tensor(transition_matrix)

    result =
      joint_prefs
      |> Nx.flatten()
      |> Nx.dot(transition_tensor)
      |> Nx.reshape({3, 3})

    alice_result = Nx.sum(result, axes: [1]) |> Nx.to_list() |> Enum.map(&round_safely/1)
    bob_result = Nx.sum(result, axes: [0]) |> Nx.to_list() |> Enum.map(&round_safely/1)

    alice_sum = Enum.sum(alice_result)
    bob_sum = Enum.sum(bob_result)

    alice_result = Enum.map(alice_result, &(&1 / alice_sum))
    bob_result = Enum.map(bob_result, &(&1 / bob_sum))

    {alice_result, bob_result}
  end

  defp joint_preference(alice_prefs, bob_prefs) do
    Nx.outer(Nx.tensor(alice_prefs), Nx.tensor(bob_prefs))
  end

  defp round_safely(value) when is_float(value), do: Float.round(value, 4)
  defp round_safely(value) when is_integer(value), do: Float.round(value * 1.0, 4)
  defp round_safely(value), do: Float.round(value * 1.0, 4)
end


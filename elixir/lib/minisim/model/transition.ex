defmodule MiniSim.Model.TransitionMatrix do
  @moduledoc """
  Transition matrix builder for two agents.
  """

  def locate({from_va, from_vb}, {to_va, to_vb}) do
    from_idx = (from_va - 1) * 3 + (from_vb - 1)
    to_idx = (to_va - 1) * 3 + (to_vb - 1)
    {from_idx, to_idx}
  end

  @doc """
  Builds a 9x9 transition matrix for two agents.
  """
  def build(alice, bob) do
    disagreements = build_disagreements_map(alice, bob)

    for row <- 0..8 do
      for col <- 0..8 do
        cond do
          Map.has_key?(disagreements, {row, col}) -> disagreements[{row, col}]
          row == col -> 1.0
          true -> 0.0
        end
      end
    end
  end

  defp build_disagreements_map(alice, bob) do
    alice_probs = choice_probabilities(alice.rho, bob.pi)
    bob_probs = choice_probabilities(bob.rho, alice.pi)

    disagreement_12 = build_disagreement_map(1, 2, alice_probs, bob_probs)
    disagreement_21 = build_disagreement_map(2, 1, bob_probs, alice_probs)

    Map.merge(disagreement_12, disagreement_21)
  end

  defp build_disagreement_map(va, vb, alice_probs, bob_probs) do
    {pa1, pa2, pa3} = alice_probs
    {pb1, pb2, pb3} = bob_probs
    %{
      locate({va, vb}, {va, vb}) => pa1 * pb1,
      locate({va, vb}, {va, va}) => pa1 * pb2,
      locate({va, vb}, {vb, vb}) => pa2 * pb1,
      locate({va, vb}, {vb, va}) => pa2 * pb2,
      locate({va, vb}, {va, 3}) => pa1 * pb3,
      locate({va, vb}, {3, vb}) => pa3 * pb1,
      locate({va, vb}, {3, 3}) => pa3 * pb3,
      locate({va, vb}, {vb, 3}) => pa2 * pb3,
      locate({va, vb}, {3, va}) => pa3 * pb2
    }
  end

  # Returns {p_keep, p_change, p_alt}
  def choice_probabilities(resistance, persuasion) do
    keep = resistance * (1 - persuasion)
    change = (1 - resistance) * persuasion
    alt = resistance * persuasion

    normalize({keep, change, alt})
  end

  defp normalize({a, b, c}) do
    total = a + b + c
    {a / total, b / total, c / total}
  end
end

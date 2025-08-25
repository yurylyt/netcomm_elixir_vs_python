defmodule MiniSim.Model.Simulation do
  @moduledoc """
  Core simulation algorithms and agent interaction functions (minimal variant).
  """

  alias MiniSim.Model.Agent
  alias MiniSim.Model.Dialog

  defmodule Statistics do
    defstruct [
      :total_agents,
      :vote_results,
      :average_preferences,
      :agent_preferences
    ]

    @type t :: %__MODULE__{
            total_agents: non_neg_integer(),
            vote_results: %{optional(integer()) => non_neg_integer()},
            average_preferences: [float()],
            agent_preferences: [[float()]]
          }
  end

  defstruct [
    :agents,
    :num_iterations,
    :iteration_stats,
    :seed,
    :tick,
    :chunk_size
  ]

  @type t :: %__MODULE__{
          agents: [Agent.t()],
          num_iterations: integer(),
          iteration_stats: [Statistics.t()],
          seed: non_neg_integer(),
          tick: non_neg_integer(),
          chunk_size: nil | pos_integer()
        }

  def new_simulation(num_iterations, seed) do
    %__MODULE__{
      agents: [],
      num_iterations: num_iterations,
      iteration_stats: [],
      seed: seed,
      tick: 0,
      chunk_size: nil
    }
  end

  # Fast path: agents as a tuple snapshot (O(1) index)
  def simulate_dialogue({alice_idx, bob_idx}, agents_tuple) when is_tuple(agents_tuple) do
    alice = elem(agents_tuple, alice_idx)
    bob = elem(agents_tuple, bob_idx)
    {alice_prefs, bob_prefs} = Dialog.talk(alice, bob)
    {alice_idx, alice_prefs, bob_idx, bob_prefs}
  end

  def get_statistics(agents) do
    # Deterministic preferences snapshot; vote computation handled externally for cross-language parity
    agent_preferences =
      agents
      |> Enum.map(fn a -> a.preferences end)
      |> Enum.map(fn [a,b,c] -> [Float.round(a, 3), Float.round(b, 3), Float.round(c, 3)] end)

    average_preferences =
      agent_preferences
      |> average_preferences()
      |> Enum.map(&Float.round(&1, 3))

    %Statistics{
      total_agents: length(agents),
      vote_results: %{},
      average_preferences: average_preferences,
      agent_preferences: agent_preferences
    }
  end

  # Always use exhaustive all-pairs matching
  def generate_pairs(simulation) do
    n = length(simulation.agents)
    for i <- 0..(n - 2), j <- (i + 1)..(n - 1), do: {i, j}
  end

  def update_agents(updates, agents) do
    preference_updates =
      Enum.reduce(updates, %{}, fn {alice_idx, alice_prefs, bob_idx, bob_prefs}, acc ->
        acc
        |> update_in([alice_idx], &add_preferences(&1 || [], alice_prefs))
        |> update_in([bob_idx], &add_preferences(&1 || [], bob_prefs))
      end)

    agents
    |> Enum.with_index()
    |> Enum.map(fn {agent, idx} ->
      case Map.get(preference_updates, idx) do
        nil -> agent
        updates ->
          averaged_prefs = average_preferences(updates)
          %{agent | preferences: averaged_prefs}
      end
    end)
  end

  # Seed derivation for random matching removed

  defp add_preferences(acc, new_prefs), do: [new_prefs | acc]
  defp average_preferences([]), do: [0.0, 0.0, 0.0]

  defp average_preferences(prefs_list) do
    count = length(prefs_list)

    prefs_list
    |> Enum.reduce([0.0, 0.0, 0.0], &sum_prefs(&1, &2))
    |> Enum.map(&(&1 / count))
  end

  defp sum_prefs([a1, a2, a3], [b1, b2, b3]) do
    [a1 + b1, a2 + b2, a3 + b3]
  end
end

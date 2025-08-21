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
    :tick
  ]

  @type t :: %__MODULE__{
          agents: [Agent.t()],
          num_iterations: integer(),
          iteration_stats: [Statistics.t()],
          seed: non_neg_integer(),
          tick: non_neg_integer()
        }

  def new_simulation(num_iterations, seed) do
    %__MODULE__{
      agents: [],
      num_iterations: num_iterations,
      iteration_stats: [],
      seed: seed,
      tick: 0
    }
  end

  def add_agent(simulation, agent, copies \\ 1) do
    %{simulation | agents: simulation.agents ++ List.duplicate(agent, copies)}
  end

  def simulate_dialogue({alice_idx, bob_idx}, agents_map) do
    {alice_update_prefs, bob_update_prefs} =
      Dialog.talk(Map.get(agents_map, alice_idx), Map.get(agents_map, bob_idx))

    {alice_idx, alice_update_prefs, bob_idx, bob_update_prefs}
  end

  def get_statistics(agents) do
    max_c = max(System.schedulers_online(), 2)

    choices =
      agents
      |> Task.async_stream(fn a -> Agent.vote(a) end,
        max_concurrency: max_c,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.map(fn {:ok, choice} -> choice end)

    agent_preferences =
      agents
      |> Task.async_stream(fn a -> a.preferences end,
        max_concurrency: max_c,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.map(fn {:ok, prefs} -> prefs end)

    average_preferences = average_preferences(agent_preferences)

    %Statistics{
      total_agents: length(agents),
      vote_results: Enum.frequencies(choices),
      average_preferences: average_preferences,
      agent_preferences: agent_preferences
    }
  end

  # Always use exhaustive all-pairs matching
  def generate_pairs(simulation) do
    generate_all_pairs(simulation.agents)
  end

  def generate_all_pairs(agents) do
    n = length(agents)
    for i <- 0..(n - 2), j <- (i + 1)..(n - 1), do: {i, j}
  end

  # Random matching removed in minimal variant

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

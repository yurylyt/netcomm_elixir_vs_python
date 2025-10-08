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
    :chunk_size,
    :topology
  ]

  @type t :: %__MODULE__{
          agents: [Agent.t()],
          num_iterations: integer(),
          iteration_stats: [Statistics.t()],
          seed: non_neg_integer(),
          tick: non_neg_integer(),
          chunk_size: nil | pos_integer(),
          topology: :all | pos_integer()
        }

  def new_simulation(num_iterations, seed) do
    %__MODULE__{
      agents: [],
      num_iterations: num_iterations,
      iteration_stats: [],
      seed: seed,
      tick: 0,
      chunk_size: nil,
      topology: :all
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

  @doc """
  Generate pairs based on topology setting.
  - :all -> all-pairs matching
  - integer k (1..n-1) -> random matching with k interactions per agent
  """
  def generate_pairs(simulation, topology \\ :all)

  def generate_pairs(simulation, :all) do
    n = length(simulation.agents)
    for i <- 0..(n - 2), j <- (i + 1)..(n - 1), do: {i, j}
  end

  def generate_pairs(simulation, k) when is_integer(k) do
    n = length(simulation.agents)
    if k < 1 or k >= n do
      raise ArgumentError, "Random matching requires k in range 1..#{n-1}, got #{k}"
    end
    generate_random_pairs(n, k, simulation.seed, simulation.tick)
  end

  defp generate_random_pairs(n, k, seed, tick) do
    # Derive a unique seed for this iteration's random matching
    iteration_seed = :erlang.phash2({seed, tick, :random_pairs})
    rng = MiniSim.Rng.new(iteration_seed)

    # Generate k random partners for each agent
    {pairs, _} = Enum.reduce(0..(n - 1), {[], rng}, fn i, {acc_pairs, r} ->
      {agent_pairs, r2} = generate_agent_pairs(i, n, k, r)
      {agent_pairs ++ acc_pairs, r2}
    end)

    # Remove duplicates and ensure i < j ordering
    pairs
    |> Enum.map(fn {i, j} -> if i < j, do: {i, j}, else: {j, i} end)
    |> Enum.uniq()
  end

  defp generate_agent_pairs(i, n, k, rng) do
    Enum.reduce(1..k, {[], rng}, fn _, {pairs, r} ->
      {j, r2} = random_partner(i, n, r)
      {[{i, j} | pairs], r2}
    end)
  end

  defp random_partner(i, n, rng) do
    {u, rng2} = MiniSim.Rng.uniform(rng)
    # Map u to [0, n-2] range, then adjust to skip i
    j_raw = trunc(u * (n - 1))
    j = if j_raw >= i, do: j_raw + 1, else: j_raw
    {j, rng2}
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

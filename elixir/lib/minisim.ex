defmodule MiniSim do
  @moduledoc """
  Minimal simulation runner with fixed network generation:
  - resistance (rho) ~ U(0,1)
  - persuasion (pi) ~ U(0,1)
  - number of agents: parameter
  - RNG seed: parameter
  - optional chunk size: controls async processing batch size
  """

  alias MiniSim.Model.{Agent, Simulation}
  alias MiniSim.Rng
  

  @doc """
  Run the simulation and return final stats.

  Parameters:
  - num_agents: number of agents
  - iterations: number of iterations (ticks)
  - seed: RNG seed for reproducibility (integer)
  - chunk_size: positive integer batch size for pair chunks (required)
  Decisiveness logic is removed; agents always vote based on preferences.
  """
  def run(num_agents, iterations, seed, chunk_size)
      when is_integer(num_agents) and num_agents > 0 and
             is_integer(iterations) and iterations >= 0 and
             is_integer(seed) and is_integer(chunk_size) and chunk_size > 0 do
    rng = Rng.new(seed)

    sim =
      iterations
      |> Simulation.new_simulation(seed)
      |> Map.put(:chunk_size, chunk_size)
      |> seed_agents(num_agents, rng)
    {sim, rng} = sim

    # initial stats
    prefs_stats = Simulation.get_statistics(sim.agents)
    {votes, rng} = vote_results(sim.agents, rng)
    initial_stats = %{prefs_stats | vote_results: votes}
    sim = %{sim | iteration_stats: [initial_stats], tick: 0}

    {sim, _rng} = Enum.reduce(1..iterations, {sim, rng}, fn _step, {acc, r} ->
      step(acc, r)
    end)

    # prepend last stats are at head; return head of iteration_stats
    List.first(sim.iteration_stats)
  end

  defp seed_agents(sim, n, rng) do
    {agents, rng} = Enum.reduce(1..n, {[], rng}, fn _, {acc, r} ->
      {agent, r2} = random_agent(r)
      {[agent | acc], r2}
    end)
    { %{sim | agents: Enum.reverse(agents)}, rng}
  end

  defp random_agent(rng) do
    {rho, rng} = Rng.uniform(rng)
    {pi, rng} = Rng.uniform(rng)
    {option1_pref, rng} = Rng.uniform(rng)
    agent = Agent.new_agent(rho, pi, option1_pref)
    {agent, rng}
  end

  defp step(%Simulation{} = sim, rng) do
    agents_map = Map.new(Enum.with_index(sim.agents, fn agent, idx -> {idx, agent} end))

    pairs =
      sim
      |> Map.take([:agents, :seed, :tick])
      |> then(fn %{agents: agents, seed: seed, tick: tick} ->
        %Simulation{agents: agents, seed: seed, tick: tick}
      end)
      |> Simulation.generate_pairs()

    updates =
      pairs
      |> Stream.chunk_every(sim.chunk_size)
      |> Task.async_stream(
        fn chunk -> Enum.map(chunk, &Simulation.simulate_dialogue(&1, agents_map)) end,
        max_concurrency: System.schedulers_online() * 2,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.flat_map(fn {:ok, chunk_results} -> chunk_results end)

    updated_agents = Simulation.update_agents(updates, sim.agents)
    prefs_stats = Simulation.get_statistics(updated_agents)
    {votes, rng} = vote_results(updated_agents, rng)
    stats = %{prefs_stats | vote_results: votes}

    {%{sim | agents: updated_agents, iteration_stats: [stats | sim.iteration_stats], tick: sim.tick + 1}, rng}
  end

  # Chunk size is mandatory; no heuristic.

  defp vote_results(agents, rng) do
    Enum.reduce(agents, {%{}, rng}, fn a, {freq, r} ->
      {u, r2} = Rng.uniform(r)
      idx = pick_index(a.preferences, u)
      {Map.update(freq, idx, 1, &(&1 + 1)), r2}
    end)
  end

  defp pick_index([p0, p1, p2], u) do
    cond do
      u <= p0 -> 0
      u <= p0 + p1 -> 1
      true -> 2
    end
  end
end

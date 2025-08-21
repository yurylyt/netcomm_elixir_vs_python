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
    # Global RNG seed for voting and any uniform draws
    :rand.seed(:exsplus, seed)

    sim =
      iterations
      |> Simulation.new_simulation(seed)
      |> Map.put(:chunk_size, chunk_size)
      |> seed_agents(num_agents)

    # initial stats
    initial_stats = Simulation.get_statistics(sim.agents)
    sim = %{sim | iteration_stats: [initial_stats], tick: 0}

    sim = Enum.reduce(1..iterations, sim, fn _step, acc ->
      step(acc)
    end)

    # prepend last stats are at head; return head of iteration_stats
    List.first(sim.iteration_stats)
  end

  defp seed_agents(sim, n) do
    agents = Enum.map(1..n, fn _ -> random_agent() end)
    %{sim | agents: agents}
  end

  defp random_agent do
    rho = :rand.uniform()
    pi = :rand.uniform()
    option1_pref = :rand.uniform() # between 0 and 1
    Agent.new_agent(rho, pi, option1_pref)
  end

  defp step(%Simulation{} = sim) do
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
    stats = Simulation.get_statistics(updated_agents)

    %{sim | agents: updated_agents, iteration_stats: [stats | sim.iteration_stats], tick: sim.tick + 1}
  end

  # Chunk size is mandatory; no heuristic.
end

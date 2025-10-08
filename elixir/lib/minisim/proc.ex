defmodule MiniSim.Proc do
  @moduledoc """
  Process-based simulation runner using GenServers.

  - Spawns a coordinator and one GenServer per agent.
  - Iterations are coordinated by broadcasting start/apply messages.
  - All-pairs matching implemented by having agent `i` initiate talks with agents `< i`.

  Entry is `run/4`, mirroring `MiniSim.run/4`. The `chunk_size` is accepted for
  signature parity but is not used in the process-based implementation.
  """

  alias MiniSim.Model.Agent
  alias MiniSim.Proc.Coordinator
  alias MiniSim.Rng

  @doc """
  Run the process-based simulation and return final stats.

  Parameters:
  - num_agents: number of agents (>0)
  - iterations: number of iterations (>=0)
  - seed: RNG seed
  - chunk_size: ignored (kept for API parity)
  - topology: :all for all-pairs, or integer k (1..n-1) for random matching with k interactions per agent
  """
  def run(num_agents, iterations, seed, _chunk_size, topology \\ :all)
      when is_integer(num_agents) and num_agents > 0 and
             is_integer(iterations) and iterations >= 0 and is_integer(seed) do
    {agents, rng} = seed_agents(num_agents, Rng.new(seed))
    # Pass RNG state (post-seeding) to the coordinator for deterministic parity
    # Also pass the original seed for pair generation
    Coordinator.run(agents, iterations, rng, topology, seed)
  end

  defp seed_agents(n, rng) do
    Enum.reduce(1..n, {[], rng}, fn _, {acc, r} ->
      {agent, r2} = random_agent(r)
      {[agent | acc], r2}
    end)
    |> then(fn {agents, r} -> {Enum.reverse(agents), r} end)
  end

  defp random_agent(rng) do
    {rho, rng} = Rng.uniform(rng)
    {pi, rng} = Rng.uniform(rng)
    {option1_pref, rng} = Rng.uniform(rng)
    agent = Agent.new_agent(rho, pi, option1_pref)
    {agent, rng}
  end

  @doc """
  Sweep community sizes from min_agents..max_agents and print wall time (ms) per run.

  Mirrors `MiniSim.sweep/6` for the base engine. Only outputs a single integer per
  line (milliseconds) for each run size.
  """
  def sweep(min_agents, max_agents, iterations, seed, chunk_size, topology \\ :all)
      when is_integer(min_agents) and min_agents >= 2 and
             is_integer(max_agents) and max_agents >= min_agents and
             is_integer(iterations) and iterations >= 0 and
             is_integer(seed) and is_integer(chunk_size) and chunk_size > 0 do
    Enum.each(min_agents..max_agents, fn n ->
      t0 = System.monotonic_time(:millisecond)
      _ = run(n, iterations, seed, chunk_size, topology)
      t1 = System.monotonic_time(:millisecond)
      IO.puts(Integer.to_string(t1 - t0))
    end)
    :ok
  end
end

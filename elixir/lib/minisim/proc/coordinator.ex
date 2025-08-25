defmodule MiniSim.Proc.Coordinator do
  @moduledoc """
  Coordinator process that orchestrates iterations:
  - Spawns N `AgentServer`s and keeps their pids with indices.
  - Broadcasts `:iteration_start` to agents.
  - Awaits `{:agent_iteration_done, idx}` from all agents (each expects N-1 updates).
  - Broadcasts `:apply_updates` and awaits `{:applied, idx}` acks.
  - Repeats for the requested number of iterations.
  - At the end, collects final agent states and returns statistics.
  """

  use GenServer
  alias MiniSim.Model.{Agent, Simulation}
  alias MiniSim.Proc.AgentServer
  alias MiniSim.Rng

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @type run_result :: Simulation.Statistics.t()

  # Public API
  def run(agents, iterations, seed) do
    {:ok, pid} = start_link(agents: agents, iterations: iterations, seed: seed)
    GenServer.call(pid, :run, :infinity)
  end

  @impl true
  def init(opts) do
    agents = Keyword.fetch!(opts, :agents)
    iterations = Keyword.fetch!(opts, :iterations)
    seed = Keyword.fetch!(opts, :seed)
    n = length(agents)

    # Spawn agent processes first with temporary empty peers.
    {:ok, agent_rows} =
      Enum.reduce_while(Enum.with_index(agents), {:ok, []}, fn {agent, idx}, {:ok, acc} ->
        case AgentServer.start_link(index: idx, agent: agent, total_agents: n, coordinator: self()) do
          {:ok, pid} -> {:cont, {:ok, [{idx, pid} | acc]}}
          other -> {:halt, other}
        end
      end)

    agent_rows = Enum.reverse(agent_rows)
    # Provide peers to each agent
    Enum.each(agent_rows, fn {idx, pid} ->
      AgentServer.set_peers(pid, agent_rows)
    end)

    state = %{
      agents: agent_rows, # list of {idx, pid}
      iterations_left: iterations,
      n: n,
      waiting_done: MapSet.new(),
      waiting_applied: MapSet.new(),
      caller: nil,
      rng: Rng.new(seed)
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:run, from, state) do
    # kick off first iteration or finish immediately
    state = %{state | caller: from}
    if state.iterations_left > 0 and state.n > 1 do
      broadcast_iteration_start(state)
      {:noreply, %{state | waiting_done: all_indices_set(state)}}
    else
      # gather stats immediately
      {:reply, final_statistics(state), state}
    end
  end

  @impl true
  def handle_info({:agent_iteration_done, idx}, state) do
    waiting_done = MapSet.delete(state.waiting_done, idx)
    if MapSet.size(waiting_done) == 0 do
      # All agents finished accumulating updates for this iteration
      Enum.each(state.agents, fn {_i, pid} -> AgentServer.apply_updates(pid) end)
      {:noreply, %{state | waiting_done: MapSet.new(), waiting_applied: all_indices_set(state)}}
    else
      {:noreply, %{state | waiting_done: waiting_done}}
    end
  end

  @impl true
  def handle_info({:applied, idx}, state) do
    waiting_applied = MapSet.delete(state.waiting_applied, idx)
    if MapSet.size(waiting_applied) == 0 do
      # Iteration completed; continue or finish
      state = %{state | waiting_applied: MapSet.new(), iterations_left: state.iterations_left - 1}
      cond do
        state.iterations_left > 0 ->
          broadcast_iteration_start(state)
          {:noreply, %{state | waiting_done: all_indices_set(state)}}
        true ->
          # produce final stats
          stats = final_statistics(state)
          GenServer.reply(state.caller, stats)
          {:noreply, state}
      end
    else
      {:noreply, %{state | waiting_applied: waiting_applied}}
    end
  end

  defp broadcast_iteration_start(state) do
    Enum.each(state.agents, fn {_idx, pid} -> AgentServer.iteration_start(pid) end)
  end

  defp all_indices_set(state) do
    state.agents |> Enum.map(&elem(&1, 0)) |> MapSet.new()
  end

  defp final_statistics(state) do
    # Collect final agents (in index order)
    agents =
      state.agents
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {_idx, pid} -> AgentServer.get_agent(pid) end)

    prefs_stats = Simulation.get_statistics(agents)
    {votes, _rng2} = vote_results(agents, state.rng)
    %{prefs_stats | vote_results: votes}
  end

  # Copied vote function to avoid coupling to MiniSim private helpers
  defp vote_results(agents, rng) do
    Enum.reduce(agents, {%{}, rng}, fn a, {freq, r} ->
      {u, r2} = Rng.uniform(r)
      idx = pick_index(a.preferences, u)
      {Map.update(freq, idx, 1, &(&1 + 1)), r2}
    end)
  end

  defp pick_index([p0, p1, _p2], u) do
    cond do
      u <= p0 -> 0
      u <= p0 + p1 -> 1
      true -> 2
    end
  end
end


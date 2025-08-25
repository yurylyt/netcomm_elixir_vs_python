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
  alias MiniSim.Model.Simulation
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

    # Spawn agent processes
    {:ok, agent_rows} =
      Enum.reduce_while(Enum.with_index(agents), {:ok, []}, fn {agent, idx}, {:ok, acc} ->
        case AgentServer.start_link(index: idx, agent: agent, total_agents: n, coordinator: self()) do
          {:ok, pid} -> {:cont, {:ok, [{idx, pid} | acc]}}
          other -> {:halt, other}
        end
      end)

    agent_rows = Enum.reverse(agent_rows)

    state = %{
      agents: agent_rows, # list of {idx, pid}
      iterations_left: iterations,
      n: n,
      waiting_contribs: MapSet.new(),
      sums: %{},
      caller: nil,
      rng: Rng.new(seed),
      snapshot_tab: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:run, from, state) do
    # kick off first iteration or finish immediately
    state = %{state | caller: from}
    if state.iterations_left > 0 and state.n > 1 do
      state = snapshot_and_broadcast(state)
      {:noreply, %{state | waiting_contribs: all_indices_set(state)}}
    else
      # gather stats immediately
      {:reply, final_statistics(state), state}
    end
  end

  @impl true
  def handle_info({:contribs, idx, partial_map}, state) do
    waiting = MapSet.delete(state.waiting_contribs, idx)
    sums = merge_sum_maps([state.sums, partial_map])
    if MapSet.size(waiting) == 0 do
      denom = max(state.n - 1, 1)
      new_prefs =
        sums
        |> Enum.map(fn {i, [a,b,c]} -> {i, [a/denom, b/denom, c/denom]} end)
        |> Map.new()

      Enum.each(state.agents, fn {i, pid} ->
        prefs = Map.get(new_prefs, i, AgentServer.get_prefs(pid))
        :ok = AgentServer.set_prefs(pid, prefs)
      end)

      if state.snapshot_tab, do: :ets.delete(state.snapshot_tab)

      state = %{state | sums: %{}, waiting_contribs: MapSet.new(), iterations_left: state.iterations_left - 1, snapshot_tab: nil}
      cond do
        state.iterations_left > 0 ->
          state2 = snapshot_and_broadcast(state)
          {:noreply, %{state2 | waiting_contribs: all_indices_set(state2)}}
        true ->
          stats = final_statistics(state)
          GenServer.reply(state.caller, stats)
          {:noreply, state}
      end
    else
      {:noreply, %{state | waiting_contribs: waiting, sums: sums}}
    end
  end

  defp snapshot_and_broadcast(state) do
    tab = :ets.new(:minisim_snapshot, [:set, :protected, read_concurrency: true])
    Enum.each(state.agents, fn {idx, pid} ->
      a = AgentServer.get_agent(pid)
      :ets.insert(tab, {idx, a})
    end)

    Enum.each(state.agents, fn {_idx, pid} -> AgentServer.iteration_start(pid, tab) end)
    %{state | snapshot_tab: tab}
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

  defp merge_sum_maps(list_of_maps) do
    Enum.reduce(list_of_maps, %{}, fn m, acc ->
      Enum.reduce(m, acc, fn {k, [a,b,c]}, acc2 ->
        Map.update(acc2, k, [a,b,c], fn [x,y,z] -> [x+a, y+b, z+c] end)
      end)
    end)
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

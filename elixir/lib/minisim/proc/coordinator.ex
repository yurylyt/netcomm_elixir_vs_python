defmodule MiniSim.Proc.Coordinator do
  @moduledoc """
  Coordinator process that orchestrates iterations:
  - Spawns N `AgentServer`s and keeps their pids with indices.
  - Broadcasts `:iteration_start` to agents.
  - Awaits `{:agent_iteration_done, idx}` from all agents (each expects N-1 updates for all-pairs,
    or k updates for random matching).
  - Broadcasts `:apply_updates` and awaits `{:applied, idx}` acks.
  - Repeats for the requested number of iterations.
  - At the end, collects final agent states and returns statistics.

  Supports both all-pairs and random matching topologies.
  """

  use GenServer
  alias MiniSim.Model.Simulation
  alias MiniSim.Proc.AgentServer
  alias MiniSim.Rng

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @type run_result :: Simulation.Statistics.t()

  # Public API
  def run(agents, iterations, rng, topology \\ :all, original_seed \\ nil) do
    seed = original_seed || rng
    {:ok, pid} = start_link(agents: agents, iterations: iterations, rng: rng, topology: topology, seed: seed)
    GenServer.call(pid, :run, :infinity)
  end

  @impl true
  def init(opts) do
    agents = Keyword.fetch!(opts, :agents)
    iterations = Keyword.fetch!(opts, :iterations)
    rng = Keyword.fetch!(opts, :rng)
    topology = Keyword.get(opts, :topology, :all)
    seed = Keyword.get(opts, :seed, rng)
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
      rng: rng,
      snapshot_tab: nil,
      topology: topology,
      tick: 0,
      seed: seed  # Original seed for pair generation
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:run, from, state) do
    # kick off first iteration or finish immediately
    state = %{state | caller: from}
    if state.iterations_left > 0 and state.n > 1 do
      # Advance RNG by initial vote draw (base engine records initial stats)
      agents_now =
        state.agents
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.map(fn {_i, pid} -> AgentServer.get_agent(pid) end)
      {_ignored_votes, rng2} = vote_results(agents_now, state.rng)
      state = %{state | rng: rng2}

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
      # Calculate averages based on actual count of contributions per agent
      new_prefs =
        sums
        |> Enum.map(fn {i, [a, b, c, count]} ->
          {i, [a/count, b/count, c/count]}
        end)
        |> Map.new()

      Enum.each(state.agents, fn {i, pid} ->
        prefs = Map.get(new_prefs, i, AgentServer.get_prefs(pid))
        :ok = AgentServer.set_prefs(pid, prefs)
      end)

      if state.snapshot_tab, do: :ets.delete(state.snapshot_tab)

      # After applying prefs, advance RNG by drawing votes for this iteration.
      # If this was the last iteration, compute and return final stats (matching base).
      state = %{state | sums: %{}, waiting_contribs: MapSet.new(), iterations_left: state.iterations_left - 1, snapshot_tab: nil}

      agents_now =
        state.agents
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.map(fn {_i, pid} -> AgentServer.get_agent(pid) end)

      {votes, rng2} = vote_results(agents_now, state.rng)
      state = %{state | rng: rng2}

      if state.iterations_left > 0 do
        # More iterations remain: proceed without replying; we already advanced RNG.
        # Increment tick for next iteration
        state2 = snapshot_and_broadcast(%{state | tick: state.tick + 1})
        {:noreply, %{state2 | waiting_contribs: all_indices_set(state2)}}
      else
        # Final stats: compute prefs stats and attach the votes we just drew.
        prefs_stats = Simulation.get_statistics(agents_now)
        stats = %{prefs_stats | vote_results: votes}
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

    # Generate pairs based on topology
    pairs = generate_pairs_for_tick(state)

    # Build partner lists for each agent
    partner_map = build_partner_map(pairs, state.n)

    Enum.each(state.agents, fn {idx, pid} ->
      partners = Map.get(partner_map, idx, [])
      AgentServer.iteration_start(pid, tab, partners)
    end)
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
      Enum.reduce(m, acc, fn {k, [a, b, c, count]}, acc2 ->
        Map.update(acc2, k, [a, b, c, count], fn [x, y, z, cnt] -> [x+a, y+b, z+c, cnt+count] end)
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

  # Generate pairs for the current tick based on topology
  defp generate_pairs_for_tick(state) do
    case state.topology do
      :all -> generate_all_pairs(state.n)
      k when is_integer(k) -> generate_random_pairs(state.n, k, state.seed, state.tick)
    end
  end

  defp generate_all_pairs(n) do
    for i <- 0..(n - 2), j <- (i + 1)..(n - 1), do: {i, j}
  end

  defp generate_random_pairs(n, k, seed, tick) do
    # Derive a unique seed for this iteration's random matching
    iteration_seed = :erlang.phash2({seed, tick, :random_pairs})
    rng = Rng.new(iteration_seed)

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
    {u, rng2} = Rng.uniform(rng)
    # Map u to [0, n-2] range, then adjust to skip i
    j_raw = trunc(u * (n - 1))
    j = if j_raw >= i, do: j_raw + 1, else: j_raw
    {j, rng2}
  end

  # Build a map of agent_index -> list of partner indices
  defp build_partner_map(pairs, _n) do
    Enum.reduce(pairs, %{}, fn {i, j}, acc ->
      acc
      |> Map.update(i, [j], &[j | &1])
      |> Map.update(j, [i], &[i | &1])
    end)
  end
end

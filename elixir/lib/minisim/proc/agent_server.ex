defmodule MiniSim.Proc.AgentServer do
  @moduledoc """
  Agent process holding immutable agent parameters and per-iteration state.

  - Holds `MiniSim.Model.Agent` struct as `agent` (rho, pi, preferences).
  - Accumulates preference updates during an iteration without mutating `agent.preferences`.
  - Notifies the coordinator when it has collected `n-1` updates (all-pairs coverage).
  - On `:apply_updates`, averages collected updates and updates `agent.preferences`.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    index = Keyword.fetch!(opts, :index)
    total_agents = Keyword.fetch!(opts, :total_agents)
    coordinator = Keyword.fetch!(opts, :coordinator)
    agent = Keyword.fetch!(opts, :agent)
    state = %{
      index: index,
      total_agents: total_agents,
      coordinator: coordinator,
      agent: agent,
      # iteration-scoped runtime data
      shards: [],
      shard_count: 0
    }

    {:ok, state}
  end

  # Public helpers
  def get_agent(pid), do: GenServer.call(pid, :get_agent)
  def get_prefs(pid), do: GenServer.call(pid, :get_prefs)
  def iteration_start(pid, snapshot_tab, shards), do: GenServer.cast(pid, {:iteration_start, snapshot_tab, shards})
  def set_prefs(pid, prefs), do: GenServer.cast(pid, {:set_prefs, prefs})

  @impl true
  def handle_call(:get_agent, _from, state) do
    {:reply, state.agent, state}
  end

  @impl true
  def handle_call(:get_prefs, _from, state) do
    {:reply, state.agent.preferences, state}
  end

  @impl true
  def handle_cast({:iteration_start, snapshot_tab, shards}, state) do
    # Compute all pairs i with j < i against snapshot from ETS.
    # Batch updates per shard to reduce message volume.
    batch_size = 256
    shard_count = length(shards)

    # We'll store shard -> list of {idx, prefs} in a map
    empty_buckets = for s <- 0..(shard_count - 1), into: %{}, do: {s, []}

    # iterate j from 0..i-1 (guard against i == 0)
    {buckets_final, _sent} =
      if state.index > 0 do
        Enum.reduce(0..(state.index - 1), {empty_buckets, 0}, fn j, {buckets, sent} ->
          alice = state.agent
          bob = get_snapshot_agent(snapshot_tab, j)

          {ap, bp} = MiniSim.Model.Dialog.talk(alice, bob)

          # route both updates to shard owners of i and j
          si = rem(state.index, shard_count)
          sj = rem(j, shard_count)

          buckets = Map.update!(buckets, si, &[{state.index, ap} | &1])
          buckets = Map.update!(buckets, sj, &[{j, bp} | &1])

          # If any bucket reached batch_size, flush it
          {buckets, sent} = maybe_flush_buckets(buckets, shards, batch_size, sent)
          {buckets, sent}
        end)
      else
        {empty_buckets, 0}
      end

    # Flush whatever remains
    Enum.each(0..(shard_count - 1), fn s ->
      case Map.get(buckets_final, s) do
        [] -> :ok
        updates -> MiniSim.Proc.Aggregator.batch(Enum.at(shards, s), updates)
      end
    end)

    # Notify aggregators this agent is done; then notify coordinator
    Enum.each(shards, &MiniSim.Proc.Aggregator.done/1)
    send(state.coordinator, {:agent_iteration_done, state.index})
    {:noreply, %{state | shards: shards, shard_count: shard_count}}
  end

  @impl true
  def handle_cast({:set_prefs, prefs}, state) do
    new_agent = %{state.agent | preferences: prefs}
    send(state.coordinator, {:applied, state.index})
    {:noreply, %{state | agent: new_agent}}
  end

  defp maybe_flush_buckets(buckets, shards, batch_size, sent) do
    Enum.reduce(0..(length(shards) - 1), {buckets, sent}, fn s, {acc_buckets, acc_sent} ->
      list = Map.fetch!(acc_buckets, s)
      if length(list) >= batch_size do
        MiniSim.Proc.Aggregator.batch(Enum.at(shards, s), list)
        {Map.put(acc_buckets, s, []), acc_sent + length(list)}
      else
        {acc_buckets, acc_sent}
      end
    end)
  end

  defp get_snapshot_agent(tab, idx) do
    case :ets.lookup(tab, idx) do
      [{^idx, agent}] -> agent
      _ -> raise "missing snapshot for agent #{inspect(idx)}"
    end
  end

  # no local averaging; aggregation is centralized
end

defmodule MiniSim.Proc.AgentServer do
  @moduledoc """
  Agent process holding immutable agent parameters and per-iteration state.

  - Holds `MiniSim.Model.Agent` struct as `agent` (rho, pi, preferences).
  - Accumulates preference updates during an iteration without mutating `agent.preferences`.
  - Notifies the coordinator when it has collected `n-1` updates (all-pairs coverage).
  - On `:apply_updates`, averages collected updates and updates `agent.preferences`.
  """

  use GenServer
  alias MiniSim.Model.Agent

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    index = Keyword.fetch!(opts, :index)
    total_agents = Keyword.fetch!(opts, :total_agents)
    coordinator = Keyword.fetch!(opts, :coordinator)
    agent = Keyword.fetch!(opts, :agent)
    peers = Keyword.get(opts, :peers, [])

    state = %{
      index: index,
      total_agents: total_agents,
      coordinator: coordinator,
      agent: agent,
      peers: peers, # list of {idx, pid}
      updates: [],
      update_count: 0,
      expected_updates: max(total_agents - 1, 0),
      done_notified?: false
    }

    {:ok, state}
  end

  # Public helpers
  def get_agent(pid), do: GenServer.call(pid, :get_agent)
  def get_prefs(pid), do: GenServer.call(pid, :get_prefs)
  def add_update(pid, prefs), do: GenServer.cast(pid, {:add_update, prefs})
  def set_peers(pid, peers), do: GenServer.cast(pid, {:set_peers, peers})
  def iteration_start(pid), do: GenServer.cast(pid, :iteration_start)
  def apply_updates(pid), do: GenServer.cast(pid, :apply_updates)

  @impl true
  def handle_call(:get_agent, _from, state) do
    {:reply, state.agent, state}
  end

  @impl true
  def handle_call(:get_prefs, _from, state) do
    {:reply, state.agent.preferences, state}
  end

  @impl true
  def handle_cast({:set_peers, peers}, state) do
    {:noreply, %{state | peers: peers}}
  end

  @impl true
  def handle_cast(:iteration_start, state) do
    # Reset accumulators for the new iteration
    state = %{state | updates: [], update_count: 0, done_notified?: false}

    # Agent i initiates talks with agents having index < i
    Enum.each(state.peers, fn {peer_idx, peer_pid} ->
      if peer_idx < state.index do
        # Get both full agents in their pre-iteration state
        alice = state.agent
        bob = GenServer.call(peer_pid, :get_agent)

        {alice_prefs, bob_prefs} = MiniSim.Model.Dialog.talk(alice, bob)
        # Accumulate own update
        send(self(), {:accumulate_local, alice_prefs})
        # Send update to the peer (asynchronous)
        GenServer.cast(peer_pid, {:add_update, bob_prefs})
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_update, prefs}, state) do
    state = %{state | updates: [prefs | state.updates], update_count: state.update_count + 1}
    maybe_notify_done(state)
  end

  @impl true
  def handle_cast(:apply_updates, state) do
    new_prefs = average_preferences(state.updates)
    new_agent = %{state.agent | preferences: new_prefs}
    # Ack to coordinator that updates are applied
    send(state.coordinator, {:applied, state.index})
    {:noreply, %{state | agent: new_agent}}
  end

  @impl true
  def handle_info({:accumulate_local, prefs}, state) do
    state = %{state | updates: [prefs | state.updates], update_count: state.update_count + 1}
    maybe_notify_done(state)
  end

  defp maybe_notify_done(%{update_count: cnt, expected_updates: exp, done_notified?: false} = state)
       when cnt >= exp and exp > 0 do
    send(state.coordinator, {:agent_iteration_done, state.index})
    {:noreply, %{state | done_notified?: true}}
  end

  defp maybe_notify_done(state), do: {:noreply, state}

  defp average_preferences([]), do: [0.0, 0.0, 0.0]
  defp average_preferences(prefs_list) do
    count = length(prefs_list)
    prefs_list
    |> Enum.reduce([0.0, 0.0, 0.0], fn [a1, a2, a3], [b1, b2, b3] -> [a1 + b1, a2 + b2, a3 + b3] end)
    |> Enum.map(&(&1 / count))
  end
end

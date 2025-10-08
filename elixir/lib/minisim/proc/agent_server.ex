defmodule MiniSim.Proc.AgentServer do
  @moduledoc """
  Agent process holding immutable agent parameters and per-iteration state.

  - Holds `MiniSim.Model.Agent` struct as `agent` (rho, pi, preferences).
  - Accumulates preference updates during an iteration without mutating `agent.preferences`.
  - Notifies the coordinator when it has collected updates from all its assigned partners.
  - On `:apply_updates`, averages collected updates and updates `agent.preferences`.

  Supports both all-pairs topology (interact with agents < i) and random matching
  (interact with specified partner list).
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
      agent: agent
    }

    {:ok, state}
  end

  # Public helpers
  def get_agent(pid), do: GenServer.call(pid, :get_agent)
  def get_prefs(pid), do: GenServer.call(pid, :get_prefs)
  def iteration_start(pid, snapshot_tab, partners), do: GenServer.cast(pid, {:iteration_start, snapshot_tab, partners})
  def set_prefs(pid, prefs), do: GenServer.call(pid, {:set_prefs, prefs}, :infinity)

  @impl true
  def handle_call(:get_agent, _from, state) do
    {:reply, state.agent, state}
  end

  @impl true
  def handle_call(:get_prefs, _from, state) do
    {:reply, state.agent.preferences, state}
  end

  @impl true
  def handle_call({:set_prefs, prefs}, _from, state) do
    new_agent = %{state.agent | preferences: prefs}
    {:reply, :ok, %{state | agent: new_agent}}
  end

  @impl true
  def handle_cast({:iteration_start, snapshot_tab, partners}, state) do
    # Compute interactions based on the provided partners list
    # Only process pairs where we are the lower-indexed agent to avoid double-counting
    # Each pair {i, j} where i < j is processed only by agent i
    contribs =
      partners
      |> Enum.filter(fn j -> j > state.index end)
      |> Enum.reduce(%{}, fn j, acc ->
        # This agent (lower index) is alice, partner (higher index) is bob
        lower = state.agent
        higher = get_snapshot_agent(snapshot_tab, j)
        {lower_prefs, higher_prefs} = MiniSim.Model.Dialog.talk(lower, higher)
        acc
        |> add_contrib(state.index, lower_prefs)
        |> add_contrib(j, higher_prefs)
      end)

    send(state.coordinator, {:contribs, state.index, contribs})
    {:noreply, state}
  end


  defp get_snapshot_agent(tab, idx) do
    case :ets.lookup(tab, idx) do
      [{^idx, agent}] -> agent
      _ -> raise "missing snapshot for agent #{inspect(idx)}"
    end
  end

  defp add_contrib(map, idx, [a, b, c]) do
    Map.update(map, idx, [a, b, c, 1], fn [x, y, z, count] -> [x + a, y + b, z + c, count + 1] end)
  end
end

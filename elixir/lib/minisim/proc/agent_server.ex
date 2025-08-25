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
      agent: agent
    }

    {:ok, state}
  end

  # Public helpers
  def get_agent(pid), do: GenServer.call(pid, :get_agent)
  def get_prefs(pid), do: GenServer.call(pid, :get_prefs)
  def iteration_start(pid, snapshot_tab), do: GenServer.cast(pid, {:iteration_start, snapshot_tab})
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
  def handle_cast({:iteration_start, snapshot_tab}, state) do
    # Compute all pairs i with j < i against snapshot from ETS.
    contribs =
      if state.index > 0 do
        Enum.reduce(0..(state.index - 1), %{}, fn j, acc ->
          alice = state.agent
          bob = get_snapshot_agent(snapshot_tab, j)
          {ap, bp} = MiniSim.Model.Dialog.talk(alice, bob)
          acc
          |> add_contrib(state.index, ap)
          |> add_contrib(j, bp)
        end)
      else
        %{}
      end

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
    Map.update(map, idx, [a, b, c], fn [x, y, z] -> [x + a, y + b, z + c] end)
  end
end

defmodule MiniSim.Proc.Aggregator do
  @moduledoc """
  Aggregates dialogue results across shards to reduce message contention.

  API:
  - cast {:batch, list_of_updates} where updates = [{idx, [p0,p1,p2]}, ...]
  - call :flush -> returns current sum_map and resets it
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, %{sums: %{}, done: 0, waiter: nil}}
  end

  def batch(pid, updates) when is_list(updates) do
    GenServer.cast(pid, {:batch, updates})
  end

  def start_iteration(pid), do: GenServer.cast(pid, :start_iteration)
  def done(pid), do: GenServer.cast(pid, :done)
  def collect(pid, n), do: GenServer.call(pid, {:collect, n}, :infinity)

  @impl true
  def handle_cast({:batch, updates}, state) do
    sums = Enum.reduce(updates, state.sums, fn {idx, [a,b,c]}, acc ->
      Map.update(acc, idx, [a,b,c], fn [x,y,z] -> [x+a, y+b, z+c] end)
    end)
    {:noreply, %{state | sums: sums}}
  end

  @impl true
  def handle_cast(:start_iteration, _state) do
    {:noreply, %{sums: %{}, done: 0, waiter: nil}}
  end

  @impl true
  def handle_cast(:done, %{waiter: nil} = state) do
    {:noreply, %{state | done: state.done + 1}}
  end

  @impl true
  def handle_cast(:done, %{waiter: {from, n}} = state) do
    done = state.done + 1
    if done >= n do
      GenServer.reply(from, state.sums)
      {:noreply, %{sums: %{}, done: 0, waiter: nil}}
    else
      {:noreply, %{state | done: done}}
    end
  end

  @impl true
  def handle_call({:collect, n}, from, %{done: done} = state) do
    if done >= n do
      {:reply, state.sums, %{sums: %{}, done: 0, waiter: nil}}
    else
      {:noreply, %{state | waiter: {from, n}}}
    end
  end
end

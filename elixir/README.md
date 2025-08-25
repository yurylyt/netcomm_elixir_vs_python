# MiniSim (Elixir) — Minimal Simulation Copy

A distilled copy of the Elixir simulation core for performance comparisons. All web, storage, and config parsing code is removed.

Fixed network configuration (always all pairs):
- resistance (`rho`) and persuasion (`pi`) are drawn from U(0,1)
- number of agents and RNG seed are parameters
- agent interactions use exhaustive all-pairs matching each tick (O(n^2))

## Run

- Install deps: `cd elixir && mix deps.get`
- Start an IEx session: `iex -S mix`
- Run a simulation (always all pairs):

```
# Base (task/async) engine
# MiniSim.run(num_agents, iterations, seed, chunk_size)
# 4th arg controls async chunk size for pair processing (required)
result = MiniSim.run(2_000, 10, 12345, 256)

# Process-based (GenServer) engine
# Same signature; chunk_size is ignored (kept for API parity)
result2 = MiniSim.Proc.run(2_000, 10, 12345, 256)

# Fields on result/result2:
# .total_agents
# .vote_results          # map: 0 | 1 | 2 => count
# .average_preferences   # [p1, p2, p3]
# .agent_preferences     # per-agent prefs (last tick)
```

## Process-Based Engine
- Coordinator `MiniSim.Proc.Coordinator` spawns one GenServer per agent and broadcasts iteration messages.
- Each agent is a GenServer (`MiniSim.Proc.AgentServer`) that:
  - On iteration start, talks to all lower-index peers (i talks to all j < i), using `MiniSim.Model.Dialog.talk/2`.
  - Accumulates `n-1` preference updates (own + peers’); notifies the coordinator when done.
  - Applies the averaged updates when the coordinator broadcasts `:apply_updates`.
- Completion detection: the coordinator waits for all `n` agents to report done, then applies updates for all and advances to the next iteration.

### Message Flow (Sequence)

```
Coordinator                                      Agent[0..n-1]
    |                                                 |
    |-- broadcast :iteration_start ------------------>|
    |                                                 |  For each agent i:
    |                                                 |   - reset accumulators
    |                                                 |   - for each j < i:
    |                                                 |       call peer j for state
    |                                                 |       talk(i, j) -> {prefs_i, prefs_j}
    |                                                 |       accumulate prefs_i locally
    |                                                 |       send {:add_update, prefs_j} to j
    |                                                 |
    |<----- {:agent_iteration_done, i} ---------------|  when agent i collected n-1 updates
    |  (from all i in 0..n-1)                         |
    |                                                 |
    |-- broadcast :apply_updates -------------------->|
    |                                                 |  each agent averages updates,
    |                                                 |  updates preferences, and acks
    |<----------- {:applied, i} ----------------------|
    |  (from all i in 0..n-1)                         |
    |                                                 |
    |--- if iterations_left > 0 -> repeat ------------|
    |--- else: collect final agents & compute stats ->|
```

## Notes
- Uses the same core math, agent, dialog, and transition logic as the main project, without Phoenix, storage, or JSON config.
- RNG control: Global RNG seeded with `:exsplus` using provided `seed`.
- Preferences are 3-valued; initial `option1_pref` ~ U(0,1) and `option2_pref = 1 - option1_pref` (option3 starts at 0.0).

## Dependency
- `{:nx, "~> 0.6.0"}` for vectorized dialog updates.

# MiniSim (Elixir) — Minimal Simulation Copy

A distilled copy of the Elixir simulation core for performance comparisons. All web, storage, and config parsing code is removed.

Fixed network configuration (always all pairs):
- resistance (`rho`) and persuasion (`pi`) are drawn from U(0,1)
- decisiveness is fixed and supplied as a parameter
- number of agents and RNG seed are parameters
- agent interactions use exhaustive all-pairs matching each tick (O(n^2))

## Run

- Install deps: `cd elixir_minimal && mix deps.get`
- Start an IEx session: `iex -S mix`
- Run a simulation (always all pairs):

```
# MiniSim.run(num_agents, iterations, seed, decisiveness)
result = MiniSim.run(2_000, 10, 12345, 0.0)

# Fields on result:
# result.total_agents
# result.vote_results          # map: 0 | 1 | 2 | :disclaim => count
# result.average_preferences   # [p1, p2, p3]
# result.agent_preferences     # per-agent prefs (last tick)
```

## Notes
- Uses the same core math, agent, dialog, and transition logic as the main project, without Phoenix, storage, or JSON config.
- RNG control: Global RNG seeded with `:exsplus` using provided `seed`.
- Preferences are 3-valued; initial `option1_pref` ~ U(0,1) and `option2_pref = 1 - option1_pref` (option3 starts at 0.0).

## Dependency
- `{:nx, "~> 0.6.0"}` for vectorized dialog updates.

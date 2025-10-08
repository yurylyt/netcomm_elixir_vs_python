# MiniSim (Elixir) — Technical Reference

Minimal simulation core for benchmarking Elixir performance against Python. This is a distilled version focusing solely on the simulation logic, with all web, storage, and configuration parsing removed.

## Quick Reference

See the main [README.md](../README.md) for full usage instructions and script documentation.

### Interactive Sessions

```elixir
# Start IEx
iex -S mix

# Base engine (async tasks)
result = MiniSim.run(2_000, 10, 12345, 256)

# Proc engine (GenServers)
result2 = MiniSim.Proc.run(2_000, 10, 12345, 256)
```

### Result Structure

Both engines return identical result maps:

```elixir
%{
  total_agents: 2000,
  vote_results: %{0 => 234, 1 => 1456, 2 => 310},  # Option => vote count
  average_preferences: [0.117, 0.728, 0.155],       # [p1, p2, p3]
  agent_preferences: [[0.1, 0.7, 0.2], ...]         # Per-agent preferences
}
```

## Architecture

### Core Modules

- `MiniSim` — Base engine (async tasks)
- `MiniSim.Proc` — Process-based engine (GenServers)
- `MiniSim.Model.Agent` — Agent state and preferences
- `MiniSim.Model.Dialog` — Pairwise interaction logic (uses Nx)
- `MiniSim.Model.Simulation` — Simulation state and statistics
- `MiniSim.Model.TransitionMatrix` — Preference update calculations
- `MiniSim.Rng` — 64-bit LCG for deterministic RNG

### Base Engine Flow

1. **Initialization**
   - Seed RNG with provided seed
   - Generate `n` agents with random `rho`, `pi`, `option1_pref` ~ U(0,1)
   - Compute initial statistics and votes

2. **Iteration** (repeated for each tick)
   - Generate all-pairs indices: `[(0,1), (0,2), ..., (n-2, n-1)]`
   - Chunk pairs by `chunk_size` and process in parallel via `Task.async_stream`
   - For each pair `(i, j)`: call `Dialog.talk/2` → get preference updates for both agents
   - Aggregate all updates and apply to agents (averaging `n-1` contributions per agent)
   - Draw votes from updated preferences using RNG
   - Store statistics for the tick

3. **Completion**
   - Return statistics from final tick

### Process-Based Engine Architecture

**Components:**
- `MiniSim.Proc.Coordinator` — Central orchestrator (GenServer)
- `MiniSim.Proc.AgentServer` — Per-agent GenServer (one per agent)

**Message Flow:**

```
Coordinator                                      Agent[0..n-1]
    |                                                 |
    |-- broadcast :iteration_start ------------------>|
    |                                                 |  For each agent i:
    |                                                 |   - Reset accumulators
    |                                                 |   - For each j < i:
    |                                                 |       • Get peer j state (synchronous call)
    |                                                 |       • Call Dialog.talk(i, j) → {prefs_i, prefs_j}
    |                                                 |       • Accumulate prefs_i locally
    |                                                 |       • Send {:add_update, prefs_j} to j (cast)
    |                                                 |
    |<----- {:agent_iteration_done, i} ---------------|  When agent i has n-1 updates
    |  (from all i in 0..n-1)                         |
    |                                                 |
    |-- broadcast :apply_updates -------------------->|
    |                                                 |  Each agent:
    |                                                 |   - Average accumulated updates
    |                                                 |   - Update preferences
    |<----------- {:applied, i} ----------------------|   - Acknowledge completion
    |  (from all i in 0..n-1)                         |
    |                                                 |
    |--- Next iteration or collect final states ----->|
```

**Key Design Decisions:**
- Agent `i` initiates talks with all `j < i` (ensures each pair talks exactly once)
- ETS table stores agent snapshots for O(1) read access during iteration
- Coordinator waits for all `n` agents before proceeding (barrier synchronization)
- RNG state is managed by Coordinator to maintain parity with base engine

### Determinism & Parity

Both engines produce **identical results** for the same inputs:
- Same agent initialization order (seeded RNG)
- Same pair processing order (deterministic iteration)
- Same vote drawing order (RNG state threaded consistently)

**Verification:**
```elixir
# Both should return identical vote_results and average_preferences
MiniSim.run(100, 5, 42, 32)
MiniSim.Proc.run(100, 5, 42, 32)
```

## Implementation Notes

### Agent Initialization

Agents are initialized with:
- `rho` (resistance) ~ U(0,1)
- `pi` (persuasion) ~ U(0,1)  
- `option1_pref` ~ U(0,1)
- `option2_pref = 1 - option1_pref`
- `option3_pref = 0.0`

Preferences sum to 1.0 throughout the simulation.

### Pair Interactions (Dialog)

Uses `MiniSim.Model.Dialog.talk/2` which:
1. Takes two agent states
2. Computes preference updates via transition matrix (Nx tensors)
3. Returns `{prefs_i, prefs_j}` — updates for both agents

### Complexity

- **Time per iteration:** O(n²) for all-pairs matching
- **Space:** O(n) for agent storage
- **Parallelism:** 
  - Base: controlled by `chunk_size` and scheduler count
  - Proc: n+1 processes (n agents + 1 coordinator)

### Dependencies

```elixir
# mix.exs
{:nx, "~> 0.6.0"}      # Vectorized tensor operations for dialog
{:complex, "~> 0.5"}   # Complex number support (transitive)
```

## Sweeping Functions

Both engines provide `sweep/5` for benchmarking across community sizes:

```elixir
# Base engine: sweep 100-1000 agents
MIX_ENV=prod mix run -e "MiniSim.sweep(100, 1_000, 10, 42, 256)"

# Proc engine: sweep 100-1000 agents
MIX_ENV=prod mix run -e "MiniSim.Proc.sweep(100, 1_000, 10, 42, 256)"
```

Output: One line per run containing elapsed milliseconds (suitable for CSV collection).

## Performance Tuning

### Base Engine

**Chunk Size (`chunk_size`):**
- Too small: High task overhead, underutilizes schedulers
- Too large: Poor load balancing, memory pressure
- Sweet spot: Typically 128-512 for 10k-100k agents
- Tune empirically: Use `sweep_chunks.sh` script

**Scheduler Count:**
- Defaults to `System.schedulers_online()` (usually = CPU cores)
- Override: `ERL_FLAGS="+S 4:4" mix run ...` (4 schedulers)

### Proc Engine

**Process Spawn Time:**
- Dominates for small `n` (< 100 agents)
- Amortized for large `n` (> 1000 agents)

**Message Passing:**
- Synchronous calls during pair talks (blocking)
- Asynchronous casts for preference updates (non-blocking)
- Barrier at iteration end (coordinator waits for all)

**Tuning:**
- Not configurable via parameters (architecture is fixed)
- Performance is inherently O(n²) in messages per iteration

## Development Tips

### Compilation

```bash
# Dev build (includes debug info)
mix compile

# Production build (optimized)
MIX_ENV=prod mix compile

# Clean and rebuild
mix clean && MIX_ENV=prod mix compile
```

### Testing Changes

```bash
# Quick verification (should print stats map)
MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(10, 2, 42, 4))"

# Parity check (base vs proc)
MIX_ENV=prod mix run -e "
  base = MiniSim.run(50, 5, 123, 16)
  proc = MiniSim.Proc.run(50, 5, 123, 16)
  IO.inspect(base.vote_results == proc.vote_results)
"
```

### Profiling

```elixir
# In IEx
iex> :fprof.trace([:start, {:procs, :all}])
iex> MiniSim.run(1000, 5, 42, 64)
iex> :fprof.trace(:stop)
iex> :fprof.profile()
iex> :fprof.analyse()
```

## Known Limitations

- No formal test suite (ExUnit tests recommended for future work)
- No configuration file support (all parameters are function args)
- No persistence (results are ephemeral unless captured by caller)
- Fixed 3-option voting model (not configurable)

## See Also

- [Main README](../README.md) — Full usage guide and scripts
- [Python README](../python/README.md) — Python implementation details

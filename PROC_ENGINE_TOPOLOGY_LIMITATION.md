# Why Elixir Proc Engine Doesn't Appear in K8 Results

## Short Answer

**The Elixir proc engine only supports all-pairs topology**. It doesn't have topology parameter support, so it's intentionally skipped for random matching (k8) benchmarks.

## Details

### Base Engine (supports topology)
```elixir
# lib/minisim.ex
def run(num_agents, iterations, seed, chunk_size, topology \\ :all)
```
- **5 parameters** including topology
- Supports `:all` (all-pairs) or integer `k` (random matching)

### Proc Engine (all-pairs only)
```elixir
# lib/minisim/proc.ex
def run(num_agents, iterations, seed, _chunk_size)
```
- **4 parameters** - no topology support
- Hardcoded to all-pairs in the implementation
- Comment in code: "All-pairs matching implemented by having agent `i` initiate talks with agents `< i`"

### Benchmark Script Behavior

In `benchmark_trials_enhanced.sh` (lines 86-95):

```bash
# Elixir Proc engine (only all-pairs topology)
if [ "$TOPOLOGY" = "all" ]; then
  echo "Benchmarking Elixir (proc engine)..."
  for i in $(seq 1 "$TRIALS"); do
    # ... run proc engine ...
  done
else
  echo "Skipping Elixir proc engine (only supports all-pairs topology)"
fi
```

This is **correct behavior** - the script skips proc for non-all topologies because the implementation doesn't support it.

## To Add Topology Support to Proc Engine

If you want proc engine in k8 results, you would need to:

### 1. Update the API signature
```elixir
# lib/minisim/proc.ex
def run(num_agents, iterations, seed, chunk_size, topology \\ :all)
```

### 2. Pass topology to coordinator
```elixir
Coordinator.run(agents, iterations, rng, topology)
```

### 3. Implement random matching in the coordinator
Currently `MiniSim.Proc.Coordinator` hardcodes all-pairs interactions. You'd need to:
- Add topology parameter to coordinator state
- When topology is integer `k`, randomly select `k` partners for each agent
- Maintain the same RNG determinism for reproducibility

### 4. Update the agent server
The `AgentServer` currently expects to interact with all other agents. It would need to:
- Accept a list of partner indices instead of assuming all-pairs
- Only process interactions with specified partners

## Current Results

- **All-pairs benchmark**: Includes both `elixir-base` and `elixir-proc`
- **Random k8 benchmark**: Only includes `elixir-base` (proc is skipped)

This is working as designed given the current implementation limitations.

## Recommendation

If you need to compare proc engine performance on random matching topology:
1. Implement topology support in the proc engine (significant work)
2. Or, acknowledge that proc engine is an all-pairs-only optimization and compare it only for all-pairs topologies

The proc engine was likely designed specifically for the all-pairs use case, so extending it to support random matching may not have been a priority.

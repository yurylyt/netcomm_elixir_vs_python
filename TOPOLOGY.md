# Topology Configuration

The simulation now supports two interaction topologies for agent communication.

## Topology Types

### 1. All-Pairs (Default)
- **Symbol:** `:all` (Elixir) or `"all"` (Python)
- **Description:** Every agent interacts with every other agent in each iteration
- **Complexity:** O(n²) - generates n(n-1)/2 interactions per iteration
- **Use case:** Maximum interaction density, worst-case stress testing

### 2. Random Matching
- **Symbol:** Integer k where 1 ≤ k < n
- **Description:** Each agent has k random interactions per iteration
- **Complexity:** O(n×k) - approximately n×k/2 unique pairs (may be less due to duplicates)
- **Use case:** Sparse networks, scalable testing, more realistic social networks

## Usage

### Elixir

```elixir
# All-pairs (default)
MiniSim.run(100, 10, 42, 256)
MiniSim.run(100, 10, 42, 256, :all)

# Random matching with 5 interactions per agent
MiniSim.run(100, 10, 42, 256, 5)

# Sweep with topology
MiniSim.sweep(100, 200, 10, 42, 256, 3)
```

### Python

```python
from minisim import run

# All-pairs (default)
stats = run(100, 10, 42, 256)
stats = run(100, 10, 42, 256, topology="all")

# Random matching with 5 interactions per agent
stats = run(100, 10, 42, 256, topology=5)
```

### Command Line

```bash
# All-pairs (default)
./run_sim.sh elixir -a 100 -i 10
./run_sim.sh python -a 100 -i 10

# Explicit all-pairs
./run_sim.sh elixir -a 100 -i 10 -t all
./run_sim.sh python -a 100 -i 10 -t all

# Random matching with 5 interactions per agent
./run_sim.sh elixir -a 100 -i 10 -t 5
./run_sim.sh python -a 100 -i 10 -t 5

# Sweep with random matching
./sweep_sim.sh elixir 100 200 -i 10 -t 3
./sweep_sim.sh python 100 200 -i 10 -t 3
```

## Implementation Details

### Random Pair Generation

For random matching with parameter k:

1. **Seed Derivation:** Each iteration uses a unique seed derived from: `hash(base_seed, iteration_tick, "random_pairs")`
2. **Pair Generation:** Each agent i selects k random partners from all other agents
3. **Deduplication:** Pairs are deduplicated and normalized to (i,j) where i < j
4. **Determinism:** Same seed produces identical random pairings across runs

### Expected Number of Pairs

- **All-pairs:** Exactly n(n-1)/2 pairs
- **Random matching (k):** 
  - Upper bound: n×k pairs (with replacement)
  - Actual: ~n×k/2 unique pairs after deduplication (depends on k and n)
  - For small k relative to n: approximately n×k/2 pairs

### Complexity Comparison

| Topology | Pairs per Iteration | Time Complexity | Space |
|----------|-------------------|-----------------|-------|
| All-pairs | n(n-1)/2 | O(n²) | O(n²) |
| Random (k) | ~n×k/2 | O(n×k) | O(n×k) |

For k << n, random matching is significantly more scalable.

## Validation

The topology parameter is validated:
- Must be `:all` or integer k where 1 ≤ k < n
- Python accepts `"all"` (string) or integer k
- Invalid values raise an error before simulation begins

## Proc Engine Note

The Elixir `proc` engine currently only supports all-pairs topology. The topology parameter is ignored for the proc engine.

## Performance Considerations

### All-Pairs
- Best for: Small communities (n < 1000), complete interaction modeling
- Challenge: Quadratic scaling limits maximum community size

### Random Matching
- Best for: Large communities (n ≥ 1000), sparse network simulation
- Tuning: Choose k based on desired average degree
  - k=3-5: Sparse network
  - k=10-20: Moderate connectivity
  - k=50+: Dense network (approaching all-pairs at high k)

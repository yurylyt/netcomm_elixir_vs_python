# MiniSim (Python) — Implementation Reference

Python port of the MiniSim benchmark with deterministic RNG and optional multiprocessing.

## Quick Reference

See the main [README.md](../README.md) for full usage instructions and script documentation.

### CLI Usage

```bash
# Single process
python python/main.py --agents 20000 --iterations 10 --seed 42 --chunk-size 256

# With multiprocessing (4 workers)
python python/main.py --agents 20000 --iterations 10 --seed 42 --chunk-size 256 --procs 4

# Sweep mode (run multiple community sizes)
python python/main.py --sweep-from 100 --sweep-to 300 --iterations 10 --seed 42 --procs 4
```

### API Usage

```python
from minisim import run

# Run simulation
stats = run(agents=20000, iterations=10, seed=42, chunk_size=256, procs=1)

# Sweep community sizes
from minisim import sweep
sweep(min_agents=100, max_agents=300, iterations=10, seed=42, chunk_size=256, procs=1)
```

## Implementation Details

### Architecture

- **RNG:** 64-bit Linear Congruential Generator (LCG), identical to Elixir
- **Determinism:** RNG is confined to the parent process regardless of `procs` setting
- **Parallelism:** When `procs > 1`, pair chunks are distributed to worker processes
- **Results:** Identical to Elixir for same parameters (agents, iterations, seed)

### Parameters

- `agents`: Community size (positive integer)
- `iterations`: Number of simulation ticks (≥ 0)
- `seed`: RNG seed for reproducibility (integer)
- `chunk_size`: Number of pair interactions per worker task
- `procs`: Number of worker processes (default: 1)

### Multiprocessing Notes

**Chunk Size (`chunk_size`):**
- Controls granularity: how many pairs each worker processes per task
- Smaller chunks → more task overhead, better load balancing
- Larger chunks → less overhead, potential imbalance
- Sweet spot depends on community size and core count

**Process Count (`procs`):**
- `procs=1`: Single-process execution (no multiprocessing overhead)
- `procs > 1`: Distributes pair computation across worker processes
- RNG remains in parent to ensure deterministic results
- Set `procs` ≤ CPU core count for best performance

**Environment Variables:**
To avoid thread oversubscription from BLAS libraries:
```bash
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
```

These are automatically set when using `main.py`.

## Cross-Language Verification

Python and Elixir implementations produce identical results:

```bash
# Python
python python/main.py -a 100 -i 5 -s 42 -c 32

# Elixir
cd elixir && MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(100, 5, 42, 32))"
```

Compare `vote_results` and `average_preferences` — they should match exactly.

## Requirements

- Python 3.10+
- No external dependencies (uses only standard library)

See `requirements.txt` for any future additions.

## See Also

- [Main README](../README.md) — Full usage guide and all scripts
- [Elixir README](../elixir/README.md) — Elixir implementation details

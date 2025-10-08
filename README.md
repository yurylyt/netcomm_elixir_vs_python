# Elixir vs Python Performance Comparison

This repository hosts a minimal simulation used to compare Elixir and Python performance on the same problem: all-pairs agent dialogue with probabilistic preference updates. The simulation is deterministic (via seeded RNG) and provides three implementations for benchmarking:

- **Elixir (base)**: Async Task engine with parallel pair processing
- **Elixir (proc)**: GenServer/Coordinator engine (one process per agent)
- **Python**: Single-process baseline with optional multiprocessing

## Repository Structure

```
.
├── elixir/              # Elixir Mix project (MiniSim core + both engines)
├── python/              # Python port with identical behavior
├── run_sim.sh           # Single run wrapper script
├── sweep_sim.sh         # Sweep community sizes from M to N agents
├── sweep_chunks.sh      # Sweep chunk sizes (parallelism tuning)
├── sweep_em_all.sh      # Comprehensive sweep across all engines
└── benchmark_*.sh/py    # Enhanced benchmarking tools (see BENCHMARKING.md)
```

## Quick Start

### Elixir

**Prerequisites:** Elixir ≥ 1.18, Erlang/OTP (matching version)

```bash
# Install and compile
cd elixir
mix deps.get && MIX_ENV=prod mix compile

# Run simulation - Base engine (async tasks)
MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(2_000, 10, 12345, 256))"

# Run simulation - Proc engine (GenServers)
MIX_ENV=prod mix run -e "IO.inspect(MiniSim.Proc.run(2_000, 10, 12345, 256))"
```

**Signature:** `MiniSim.run(num_agents, iterations, seed, chunk_size)`
- `num_agents`: Community size (positive integer)
- `iterations`: Number of simulation ticks (≥0)
- `seed`: RNG seed for reproducibility
- `chunk_size`: Batch size for async processing (base engine only; proc ignores it)

### Python

**Prerequisites:** Python 3.10+

```bash
# Install dependencies (if any)
pip install -r python/requirements.txt

# Run simulation (single process)
python python/main.py --agents 2000 --iterations 10 --seed 12345 --chunk-size 256

# Run with multiprocessing (4 workers)
python python/main.py --agents 2000 --iterations 10 --seed 12345 --chunk-size 256 --procs 4
```

## Implementation Details

### Elixir — Base Engine (`MiniSim`)
- **Entry:** `MiniSim.run(num_agents, iterations, seed, chunk_size)`
- **Processing:** All-pairs matching per tick; pairs processed in parallel via `Task.async_stream`
- **Concurrency:** `chunk_size` controls batch size for parallel processing
- **RNG:** Shared 64-bit LCG threaded through pipeline for determinism
- **Best for:** Maximum performance on most hardware

### Elixir — Proc Engine (`MiniSim.Proc`)
- **Entry:** `MiniSim.Proc.run(num_agents, iterations, seed, chunk_size)` (chunk_size ignored)
- **Architecture:** One GenServer per agent + Coordinator process
- **Processing:** On each tick:
  1. Coordinator snapshots agent states to ETS
  2. Broadcasts iteration start to all agents
  3. Each agent i talks to all j < i, accumulates updates
  4. Coordinator collects completion signals, broadcasts apply
  5. Agents update preferences and acknowledge
- **Determinism:** RNG state matches base engine for identical results with same seed
- **Best for:** Understanding actor model patterns, studying process orchestration

### Python
- **Entry:** `run(agents, iterations, seed, chunk_size, procs=1)`
- **Processing:** All-pairs matching with optional multiprocessing over chunks
- **RNG:** Same 64-bit LCG algorithm as Elixir for cross-language parity
- **Determinism:** RNG confined to parent process regardless of `procs` setting
- **Note:** `chunk_size` controls pairs per worker task when `procs > 1`

## Scripts Reference

### `run_sim.sh` — Single Simulation Run

Wrapper script for running a single simulation and measuring wall time.

```bash
./run_sim.sh <language> --agents N --iterations N [OPTIONS]
```

**Options:**
- `-a, --agents N`: Community size (required)
- `-i, --iterations N`: Number of ticks (required)
- `-s, --seed N`: RNG seed (default: 42)
- `-c, --chunk-size N`: Batch size (default: 256)
- `-E, --engine ENGINE`: Elixir engine: `base` or `proc` (default: base)
- `-p, --procs N`: Python worker processes (default: 1)
- `-v, --verbose`: Print program output to stdout
- `-h, --help`: Show help

**Examples:**
```bash
# Elixir base engine
./run_sim.sh elixir -a 20000 -i 10 -s 42 -c 256

# Elixir proc engine
./run_sim.sh elixir -a 20000 -i 10 -E proc

# Python with 4 workers
./run_sim.sh python -a 20000 -i 10 -p 4
```

**Output:** Prints elapsed milliseconds to stdout

### `sweep_sim.sh` — Community Size Sweep

Sweep community sizes from MIN to MAX agents, running one simulation per size.

```bash
./sweep_sim.sh <language> <min_agents> <max_agents> --iterations N [OPTIONS]
```

**Options:**
- `-i, --iterations N`: Number of ticks per run (required)
- `-s, --seed N`: RNG seed (default: 42)
- `-c, --chunk-size N`: Batch size (default: 256)
- `-E, --engine ENGINE`: Elixir engine: `base` or `proc` (default: base)
- `-p, --procs N`: Python worker processes (default: 1)

**Examples:**
```bash
# Elixir base: sweep 100-300 agents
./sweep_sim.sh elixir 100 300 -i 100 -E base

# Elixir proc: sweep 100-300 agents
./sweep_sim.sh elixir 100 300 -i 100 -E proc

# Python: sweep 100-300 agents with 8 workers
./sweep_sim.sh python 100 300 -i 100 -p 8
```

**Output:** One line per run containing elapsed milliseconds

### `sweep_chunks.sh` — Chunk Size Tuning

Sweep chunk sizes from 1 to 1024 to find optimal parallelism settings.

**Configuration** (edit script to customize):
- `COMM_SIZE=200`: Fixed community size
- `MIN_CHUNK_SIZE=1`: Minimum chunk size
- `MAX_CHUNK_SIZE=1024`: Maximum chunk size
- `ITERS=100`: Iterations per run

**Usage:**
```bash
./sweep_chunks.sh [NUM_PROCS]  # NUM_PROCS for Python (optional, default: 1)
```

**Output:** One line per chunk size containing elapsed milliseconds

### `sweep_em_all.sh` — Comprehensive Sweep

Convenience script that runs community size sweeps for all three engines.

**Configuration** (edit script to customize):
- `MIN_AGENTS=100`: Starting community size
- `MAX_AGENTS=300`: Ending community size
- `ITERS=100`: Iterations per run
- `PROCS=8`: Python worker processes

**Usage:**
```bash
./sweep_em_all.sh
```

**Output:** Three sweep sections (Elixir Base, Elixir Proc, Python multi-process)

## Benchmarking Guidelines

### Quick Start - Enhanced Benchmarking

For comprehensive benchmarking with **walltime**, **memory footprint**, and **CPU usage** metrics:

```bash
# Install dependencies
pip install -r python/requirements.txt

# Run multiple trials with full metrics
./benchmark_trials_enhanced.sh -a 300 -i 10 -t 5

# Single run with metrics
./benchmark_monitor.py elixir -a 100 -i 10 -E base
```

**See [BENCHMARKING.md](BENCHMARKING.md) for complete documentation.**

### Fair Comparison Checklist
- ✅ Use identical parameters (agents, iterations, seed) across languages
- ✅ Use production builds: `MIX_ENV=prod` for Elixir
- ✅ Warm up runtimes: run 1-2 iterations before measuring
- ✅ Collect multiple trials (≥5) and compute mean/median/stddev
- ✅ Use consistent CPU/power settings (disable turbo boost, fix frequencies)
- ✅ Record system info: CPU model, core count, RAM, OS version

### Measurements to Collect
- **Wall time** (ms): Total elapsed time
- **CPU usage** (%): Average CPU utilization (>100% = multi-core)
- **Max RSS** (KB): Peak memory usage
- **System info**: Hardware and software configuration

### Enhanced Benchmark Tools ✨

The repository now includes enhanced benchmarking tools:

- **`benchmark_monitor.py`** - Python-based monitoring with `psutil` for accurate metrics
- **`benchmark_trials_enhanced.sh`** - Multi-trial runner with statistical analysis

These tools measure:
- ⏱️ **Walltime** (milliseconds)
- 💾 **Memory footprint** (peak KB)
- 🔥 **CPU usage** (average % across all cores)

**Example output:**
```
Configuration        Metric          Mean         Median       StdDev      
---------------------------------------------------------------------------
elixir-base          Walltime (ms)       1234.5       1230.0         45.2
                     Memory (KB)        45678.0      45500.0        234.5
                     CPU (%)              125.5        124.0          5.3
```

### Legacy Benchmark Command (macOS/Linux)
```bash
/usr/bin/time -l MIX_ENV=prod mix run -e "MiniSim.run(20_000, 10, 42, 256)"
```

## Reproducibility

Both implementations use the same **64-bit Linear Congruential Generator (LCG)** for deterministic behavior:
- Same `seed` → Same agent initialization → Same preference updates → Same voting results
- Cross-language verification: Run with identical parameters and compare outputs
- RNG state is threaded through the pipeline (Elixir) or confined to parent (Python)

**Verification Example:**
```bash
# Elixir
MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(100, 5, 42, 32))"

# Python
python python/main.py -a 100 -i 5 -s 42 -c 32
```

Both should produce identical `vote_results` and `average_preferences`.

## Results Template

Track your benchmarks in CSV or Markdown format:

```csv
language,engine,agents,iterations,seed,chunk_size,procs,wall_ms,cpu_ms,max_rss_kb
elixir,base,10000,10,42,256,1,1234,4567,89012
elixir,proc,10000,10,42,256,1,1456,5234,95678
python,single,10000,10,42,256,1,2345,2345,76543
python,multi,10000,10,42,256,8,987,6543,123456
```

## Engine Selection Guide

**When to use Elixir Base (`--engine base`):**
- Maximum throughput and lowest latency
- Production benchmarks
- Default choice for performance comparisons

**When to use Elixir Proc (`--engine proc`):**
- Understanding actor model / process orchestration patterns
- Studying message-passing concurrency
- Educational purposes or architectural exploration
- Results are deterministically identical to base engine

**When to use Python:**
- Baseline comparison against dynamic language
- Testing multiprocessing overhead vs Elixir's lightweight processes
- Cross-language algorithm verification

## Further Reading

- See `elixir/README.md` for detailed Elixir implementation notes and process flow diagrams
- See `python/README.md` for Python-specific API and multiprocessing details

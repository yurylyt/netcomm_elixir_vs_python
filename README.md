# Elixir vs Python Performance Comparison

This repository hosts a minimal simulation used to compare Elixir and Python performance on the same problem (all‑pairs agent dialogue with simple probabilistic updates). There are three implementations for side‑by‑side benchmarking:

- Elixir (base): async Task engine
- Elixir (proc): GenServer/Coordinator engine
- Python: single process with optional multiprocessing

## Repository Layout
- `elixir/`: Mix project containing the Elixir MiniSim core (`MiniSim` and `MiniSim.Model.*`) and both engines.
- `python/`: Python port with identical behavior and parameters.

## Implementations
- Elixir — base (async tasks):
  - Module: `MiniSim`
  - Entry: `MiniSim.run(num_agents, iterations, seed, chunk_size)`
  - All‑pairs per tick; pairs are processed in parallel using `Task.async_stream` with `chunk_size` controlling batch size.
  - Uses a shared 64‑bit LCG RNG wired through the pipeline to ensure determinism across runs.

- Elixir — proc (GenServer):
  - Module: `MiniSim.Proc`
  - Entry: `MiniSim.Proc.run(num_agents, iterations, seed, chunk_size)` (chunk size is ignored for parity only)
  - One GenServer per agent plus a Coordinator. On each tick, the Coordinator snapshots agents (ETS), broadcasts start, collects contributions from agents i for all j < i, merges deterministically, applies preferences, and draws votes.
  - RNG state is passed from `MiniSim.Proc.run/4` into the Coordinator and consumed in the same order as the base engine. Results match the base engine for the same seed and parameters.

- Python:
  - CLI: `python3 python/main.py --agents N --iterations N --seed S --chunk-size C [--procs P]`
  - Library: `from minisim import run; run(agents, iterations, seed, chunk_size, procs=1)`
  - Single‑process baseline with optional multiprocessing over chunks for pair computation.
  - Uses the same 64‑bit LCG RNG for deterministic parity with Elixir.

## Elixir: Quick Start
Prereqs: Elixir ≥ 1.18 and Erlang/OTP matching your Elixir, internet access for deps (first run).

- Install and compile:
  - `cd elixir`
  - `mix deps.get && MIX_ENV=prod mix compile`
- Run a simulation (example):
  - Base (async tasks):
    - `MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(2_000, 10, 12345, 256))"`
    - Signature: `MiniSim.run(num_agents, iterations, seed, chunk_size)`
    - `chunk_size` tunes async batch size for pair processing (required).
  - Process-based (GenServer):
    - `MIX_ENV=prod mix run -e "IO.inspect(MiniSim.Proc.run(2_000, 10, 12345, 256))"`
    - Signature: `MiniSim.Proc.run(num_agents, iterations, seed, chunk_size)`
    - `chunk_size` is ignored (kept for API parity).
- Benchmark (simple):
  - `/usr/bin/time -l MIX_ENV=prod mix run -e "MiniSim.run(20_000, 10, 42, 256)"`
  - Prefer consistent CPU/power settings; run multiple trials and average.
  - Process-based sweep:
    - `MIX_ENV=prod mix run -e "MiniSim.Proc.sweep(5_000, 20_000, 10, 42, 256)"`

## Runner Script
- Script: `./run_sim.sh <language> --agents N --iterations N [--seed N] [--chunk-size N] [--engine base|proc] [--procs N]`
- Example (Elixir): `./run_sim.sh elixir --agents 20000 --iterations 10 --seed 42 --chunk-size 256`
- Example (Python, 4 procs): `./run_sim.sh python --agents 20000 --iterations 10 --seed 42 --chunk-size 256 --procs 4`
- Notes:
  - `language`: `elixir` or `python`.
  - `chunk-size` controls async batch size (Elixir) or per-task pairs (Python).
  - `procs` applies to Python only (number of worker processes).
  - `--engine`: choose Elixir engine (`base` or `proc`); defaults to `base`.

### Choosing an engine (Elixir)
- Use `--engine base` for fastest performance on most hosts (async tasks, chunked).
- Use `--engine proc` to exercise the GenServer orchestration model; parity with base is guaranteed for identical inputs.

## Python
Python implementation supports optional multiprocessing:
- CLI: `python python/main.py --agents 20000 --iterations 10 --seed 42 --chunk-size 256 --procs 4`
- API: `from minisim import run; run(agents, iterations, seed, chunk_size, procs=1)`
- Environment: Python 3.10+, see `python/requirements.txt`.

## Fair Benchmarking Tips
- Use identical parameters across languages (agents, iterations, seed).
- Use production builds/settings (e.g., `MIX_ENV=prod`).
- Warm up runtimes before measuring; collect ≥ 5 trials.
- Record: wall time, CPU time, memory, and system info (CPU model, cores).

## Reproducibility
- RNG: both versions accept a numeric `seed` for deterministic runs.
- Document command lines and environment in your results.

## Results
Keep a simple CSV or Markdown note with columns: language, agents, iters, seed, wall_ms, cpu_ms, max_rss.

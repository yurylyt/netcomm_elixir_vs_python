# Elixir vs Python Performance Comparison

This repository hosts a minimal simulation used to compare Elixir and Python performance on the same problem (all‑pairs agent dialogue with simple probabilistic updates). The Elixir implementation is available now; the Python counterpart will be added under `python/` for side‑by‑side benchmarking.

## Repository Layout
- `elixir/`: Mix project containing the Elixir MiniSim core (`MiniSim` and `MiniSim.Model.*`).
- `python/`: Planned Python port with identical behavior and parameters.
- `AGENTS.md`: Contributor guidelines for structure, style, and workflow.

## Elixir: Quick Start
Prereqs: Elixir ≥ 1.18 and Erlang/OTP matching your Elixir, internet access for deps (first run).

- Install and compile:
  - `cd elixir`
  - `mix deps.get && MIX_ENV=prod mix compile`
- Run a simulation (example):
  - `MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(2_000, 10, 12345, 256))"`
  - Signature: `MiniSim.run(num_agents, iterations, seed, chunk_size)`
  - `chunk_size` tunes async batch size for pair processing (required).
- Benchmark (simple):
  - `/usr/bin/time -l MIX_ENV=prod mix run -e "MiniSim.run(20_000, 10, 42, 256)"`
  - Prefer consistent CPU/power settings; run multiple trials and average.

## Runner Script
- Script: `./run_sim.sh <language> --agents N --iterations N [--seed N] [--chunk-size N] [--procs N]`
- Example (Elixir): `./run_sim.sh elixir --agents 20000 --iterations 10 --seed 42 --chunk-size 256`
- Example (Python, 4 procs): `./run_sim.sh python --agents 20000 --iterations 10 --seed 42 --chunk-size 256 --procs 4`
- Notes:
  - `language`: `elixir` or `python`.
  - `chunk-size` controls async batch size (Elixir) or per-task pairs (Python).
  - `procs` applies to Python only (number of worker processes).

## Python: Status
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

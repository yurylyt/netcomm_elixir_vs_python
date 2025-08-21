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
  - `MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(2_000, 10, 12345, 0.0))"`
  - Signature: `MiniSim.run(num_agents, iterations, seed, decisiveness)`
- Benchmark (simple):
  - `/usr/bin/time -l MIX_ENV=prod mix run -e "MiniSim.run(20_000, 10, 42, 0.1)"`
  - Prefer consistent CPU/power settings; run multiple trials and average.

## Python: Status
The Python implementation will mirror the Elixir API:
- CLI/entry: `python/main.py --agents 20000 --iters 10 --seed 42 --decisiveness 0.1`
- Environment: Python 3.10+, `requirements.txt` (to be added).

## Fair Benchmarking Tips
- Use identical parameters across languages (agents, iterations, seed, decisiveness).
- Use production builds/settings (e.g., `MIX_ENV=prod`).
- Warm up runtimes before measuring; collect ≥ 5 trials.
- Record: wall time, CPU time, memory, and system info (CPU model, cores).

## Reproducibility
- RNG: both versions accept a numeric `seed` for deterministic runs.
- Document command lines and environment in your results.

## Results
Keep a simple CSV or Markdown note with columns: language, agents, iters, seed, decisiveness, wall_ms, cpu_ms, max_rss.


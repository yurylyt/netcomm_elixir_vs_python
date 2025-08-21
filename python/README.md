# MiniSim (Python) — Scaffold

This is a scaffold for the Python port of the MiniSim benchmark used for Elixir vs Python performance comparisons.

Status
- CLI and package skeleton exist.
- Core `run(agents, iterations, seed, chunk_size)` API is defined but not implemented.
- Invoking the CLI exits with code 2 and prints a Not Implemented message.

Usage (scaffold)
- `python python/main.py --agents 20000 --iterations 10 --seed 42 --chunk-size 256`
- Exit status: 2 (not implemented)

Next Steps
- Implement identical logic to Elixir’s `MiniSim.run/4`.
- Add tests (e.g., `pytest`) and ensure RNG parity via `random.seed(seed)` and `numpy.random.Generator` if needed.
- Add a lightweight results writer or integrate with the project’s runner script.


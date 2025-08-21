# MiniSim (Python)

Python port of the MiniSim benchmark with deterministic RNG and optional multiprocessing.

Status
- Core API implemented with identical behavior to Elixir variant for seeding, updates, and voting.
- Multiprocessing support via per-chunk parallelism (no RNG in workers for reproducibility).

CLI Usage
- `python python/main.py --agents 20000 --iterations 10 --seed 42 --chunk-size 256 --procs 4`

API
- `from minisim import run`
- `run(agents: int, iterations: int, seed: int, chunk_size: int, procs: int = 1) -> dict`

Notes
- `chunk_size` controls how many pair interactions each worker processes per task.
- `procs=1` runs sequentially; increase to use multiple processes. RNG is confined to the parent process to keep results deterministic across different `procs` settings.

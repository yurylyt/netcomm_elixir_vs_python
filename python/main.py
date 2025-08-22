from __future__ import annotations

import argparse
import json
import sys

from minisim import run


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="MiniSim (Python) CLI — scaffold")
    p.add_argument("--agents", "-a", type=int, required=False, help="number of agents (>0)")
    p.add_argument("--iterations", "--iters", "-i", type=int, required=True, help="iterations (>=0)")
    p.add_argument("--seed", "-s", type=int, default=42, help="RNG seed (int)")
    p.add_argument("--chunk-size", "-c", type=int, default=256, help="batch size for pair processing (>0)")
    p.add_argument("--procs", "-p", type=int, default=1, help="number of worker processes (>=1)")
    p.add_argument("--sweep-to", type=int, default=None, help="if set, run sweep from 2..N and print wall ms per run")
    return p.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    # Avoid thread oversubscription from BLAS libraries in workers
    import os
    os.environ.setdefault("OMP_NUM_THREADS", "1")
    os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
    os.environ.setdefault("MKL_NUM_THREADS", "1")

    if args.sweep_to is not None:
        # Sweep mode: print only wall ms per run
        from minisim import sweep
        sweep(args.sweep_to, args.iterations, args.seed, args.chunk_size, args.procs)
    else:
        if args.agents is None:
            raise SystemExit("--agents is required unless --sweep-to is provided")
        stats = run(args.agents, args.iterations, args.seed, args.chunk_size, args.procs)
        sys.stdout.write(json.dumps(stats) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

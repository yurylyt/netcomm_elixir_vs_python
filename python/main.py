from __future__ import annotations

import argparse
import json
import sys

from minisim import run


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="MiniSim (Python) CLI — scaffold")
    p.add_argument("--agents", "-a", type=int, required=True, help="number of agents (>0)")
    p.add_argument("--iterations", "--iters", "-i", type=int, required=True, help="iterations (>=0)")
    p.add_argument("--seed", "-s", type=int, default=42, help="RNG seed (int)")
    p.add_argument("--chunk-size", "-c", type=int, default=256, help="batch size for pair processing (>0)")
    return p.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    stats = run(args.agents, args.iterations, args.seed, args.chunk_size)
    sys.stdout.write(json.dumps(stats) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

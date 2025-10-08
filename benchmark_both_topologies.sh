#!/usr/bin/env bash
set -euo pipefail

# Comprehensive benchmark comparing all-pairs vs random matching topology
# Runs multiple trials for both topologies and saves results to separate CSV files

AGENTS=300
ITERS=10
PROCS=8
TRIALS=5
CHUNK_SIZE=256
RANDOM_K=8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<USAGE
Usage: $0 [OPTIONS]
  -a, --agents        Community size (default: 300)
  -i, --iterations    Number of iterations (default: 100)
  -t, --trials        Number of trials per configuration (default: 5)
  -p, --procs         Python worker processes (default: 8)
  -c, --chunk-size    Batch size (default: 256)
  -k, --random-k      K value for random matching topology (default: 8)
  -h, --help          Show this help

Requirements:
  pip install psutil
USAGE
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--agents)
      AGENTS="${2:-}"; shift 2 ;;
    -i|--iterations)
      ITERS="${2:-}"; shift 2 ;;
    -t|--trials)
      TRIALS="${2:-}"; shift 2 ;;
    -p|--procs)
      PROCS="${2:-}"; shift 2 ;;
    -c|--chunk-size)
      CHUNK_SIZE="${2:-}"; shift 2 ;;
    -k|--random-k)
      RANDOM_K="${2:-}"; shift 2 ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown option: $1" >&2; usage ;;
  esac
done

echo "================================================"
echo "COMPREHENSIVE TOPOLOGY BENCHMARK"
echo "================================================"
echo ""
echo "Configuration:"
echo "  Agents: $AGENTS"
echo "  Iterations: $ITERS"
echo "  Trials per config: $TRIALS"
echo "  Chunk size: $CHUNK_SIZE"
echo "  Python workers: $PROCS"
echo "  Random matching k: $RANDOM_K"
echo ""
echo "This will run benchmarks for:"
echo "  1. All-pairs topology (exhaustive)"
echo "  2. Random matching topology (k=$RANDOM_K)"
echo ""

# Run all-pairs benchmark
echo "================================================"
echo "PHASE 1: ALL-PAIRS TOPOLOGY"
echo "================================================"
echo ""
"$SCRIPT_DIR/benchmark_trials_enhanced.sh" \
  -a "$AGENTS" \
  -i "$ITERS" \
  -t "$TRIALS" \
  -p "$PROCS" \
  -c "$CHUNK_SIZE" \
  -T "all" \
  -o "benchmark_results_all_pairs.csv"

echo ""
echo "================================================"
echo "PHASE 2: RANDOM MATCHING TOPOLOGY (k=$RANDOM_K)"
echo "================================================"
echo ""
"$SCRIPT_DIR/benchmark_trials_enhanced.sh" \
  -a "$AGENTS" \
  -i "$ITERS" \
  -t "$TRIALS" \
  -p "$PROCS" \
  -c "$CHUNK_SIZE" \
  -T "$RANDOM_K" \
  -o "benchmark_results_random_k${RANDOM_K}.csv"

echo ""
echo "================================================"
echo "BENCHMARK COMPLETE"
echo "================================================"
echo ""
echo "Results saved to:"
echo "  - benchmark_results_all_pairs.csv"
echo "  - benchmark_results_random_k${RANDOM_K}.csv"
echo ""
echo "To compare results, use:"
echo "  python3 -c 'import pandas as pd; print(pd.read_csv(\"benchmark_results_all_pairs.csv\").groupby([\"language\",\"engine\"]).agg({\"walltime_ms\":\"mean\"}).round(1))'"
echo "  python3 -c 'import pandas as pd; print(pd.read_csv(\"benchmark_results_random_k${RANDOM_K}.csv\").groupby([\"language\",\"engine\"]).agg({\"walltime_ms\":\"mean\"}).round(1))'"
echo ""

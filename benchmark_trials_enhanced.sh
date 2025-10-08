#!/usr/bin/env bash
set -euo pipefail

# Enhanced multi-trial benchmarking using Python monitor for accurate metrics
# Requires: psutil (pip install psutil)

AGENTS=300
ITERS=10
PROCS=8
TRIALS=5
CHUNK_SIZE=256
TOPOLOGY="all"
OUTPUT_FILE="benchmark_results.csv"

usage() {
  cat >&2 <<USAGE
Usage: $0 [OPTIONS]
  -a, --agents        Community size (default: 300)
  -i, --iterations    Number of iterations (default: 10)
  -t, --trials        Number of trials per configuration (default: 5)
  -p, --procs         Python worker processes (default: 8)
  -c, --chunk-size    Batch size (default: 256)
  -T, --topology      Topology: 'all' for all-pairs or integer k for random matching (default: all)
  -o, --output        Output CSV file (default: benchmark_results.csv)
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
    -T|--topology)
      TOPOLOGY="${2:-}"; shift 2 ;;
    -o|--output)
      OUTPUT_FILE="${2:-}"; shift 2 ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown option: $1" >&2; usage ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/benchmark_monitor.py"

# Check if psutil is installed
if ! python3 -c "import psutil" 2>/dev/null; then
  echo "Error: psutil is not installed. Install it with: pip install psutil" >&2
  exit 1
fi

# Create CSV header
echo "language,engine,trial,agents,iterations,chunk_size,procs,topology,walltime_ms,max_memory_kb,avg_cpu_percent" > "$OUTPUT_FILE"

echo "Running benchmarks with:"
echo "  Agents: $AGENTS"
echo "  Iterations: $ITERS"
echo "  Trials: $TRIALS"
echo "  Chunk size: $CHUNK_SIZE"
echo "  Python procs: $PROCS"
echo "  Topology: $TOPOLOGY"
echo "  Output: $OUTPUT_FILE"
echo ""

# Elixir Base engine
echo "Benchmarking Elixir (base engine)..."
for i in $(seq 1 "$TRIALS"); do
  echo "  Trial $i/$TRIALS"
  RESULT=$(python3 "$MONITOR_SCRIPT" elixir -a $AGENTS -i $ITERS -c $CHUNK_SIZE -E base -t $TOPOLOGY -o csv)
  echo "elixir,base,$i,$AGENTS,$ITERS,$CHUNK_SIZE,1,$TOPOLOGY,$RESULT" >> "$OUTPUT_FILE"
done

# Elixir Proc engine (now supports all topologies)
echo "Benchmarking Elixir (proc engine)..."
for i in $(seq 1 "$TRIALS"); do
  echo "  Trial $i/$TRIALS"
  RESULT=$(python3 "$MONITOR_SCRIPT" elixir -a $AGENTS -i $ITERS -c $CHUNK_SIZE -E proc -t $TOPOLOGY -o csv)
  echo "elixir,proc,$i,$AGENTS,$ITERS,$CHUNK_SIZE,1,$TOPOLOGY,$RESULT" >> "$OUTPUT_FILE"
done

# Python single-process
# echo "Benchmarking Python (single-process)..."
# for i in $(seq 1 "$TRIALS"); do
#   echo "  Trial $i/$TRIALS"
#   RESULT=$(python3 "$MONITOR_SCRIPT" python -a $AGENTS -i $ITERS -c $CHUNK_SIZE -p 1 -t $TOPOLOGY -o csv)
#   echo "python,single,$i,$AGENTS,$ITERS,$CHUNK_SIZE,1,$TOPOLOGY,$RESULT" >> "$OUTPUT_FILE"
# done

# Python multi-process
echo "Benchmarking Python (multi-process)..."
for i in $(seq 1 "$TRIALS"); do
  echo "  Trial $i/$TRIALS"
  RESULT=$(python3 "$MONITOR_SCRIPT" python -a $AGENTS -i $ITERS -c $CHUNK_SIZE -p $PROCS -t $TOPOLOGY -o csv)
  echo "python,multi,$i,$AGENTS,$ITERS,$CHUNK_SIZE,$PROCS,$TOPOLOGY,$RESULT" >> "$OUTPUT_FILE"
done

echo ""
echo "Benchmarking complete! Results saved to $OUTPUT_FILE"
echo ""
echo "Summary statistics:"
echo ""

# Display summary
python3 - "$OUTPUT_FILE" <<'PYTHON'
import sys
import csv
from collections import defaultdict

filename = sys.argv[1]

data = defaultdict(lambda: {"walltime": [], "memory": [], "cpu": []})

with open(filename, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        key = f"{row['language']}-{row['engine']}"
        data[key]["walltime"].append(float(row["walltime_ms"]))
        data[key]["memory"].append(float(row["max_memory_kb"]))
        data[key]["cpu"].append(float(row["avg_cpu_percent"]))

def avg(lst):
    return sum(lst) / len(lst) if lst else 0

def median(lst):
    sorted_lst = sorted(lst)
    n = len(sorted_lst)
    if n == 0:
        return 0
    if n % 2 == 1:
        return sorted_lst[n // 2]
    return (sorted_lst[n // 2 - 1] + sorted_lst[n // 2]) / 2

def stddev(lst):
    if len(lst) < 2:
        return 0
    mean = avg(lst)
    variance = sum((x - mean) ** 2 for x in lst) / len(lst)
    return variance ** 0.5

print(f"{'Configuration':<20} {'Metric':<15} {'Mean':<12} {'Median':<12} {'StdDev':<12}")
print("-" * 75)

for key in sorted(data.keys()):
    metrics = data[key]
    print(f"{key:<20} {'Walltime (ms)':<15} {avg(metrics['walltime']):>11.1f} {median(metrics['walltime']):>11.1f} {stddev(metrics['walltime']):>11.1f}")
    print(f"{'':<20} {'Memory (KB)':<15} {avg(metrics['memory']):>11.1f} {median(metrics['memory']):>11.1f} {stddev(metrics['memory']):>11.1f}")
    print(f"{'':<20} {'CPU (%)':<15} {avg(metrics['cpu']):>11.1f} {median(metrics['cpu']):>11.1f} {stddev(metrics['cpu']):>11.1f}")
    print()
PYTHON

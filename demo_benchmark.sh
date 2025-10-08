#!/usr/bin/env bash
# Quick demo of enhanced benchmarking capabilities

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==================================================================="
echo "Enhanced Benchmarking Demo"
echo "==================================================================="
echo ""

# Check if psutil is installed
if ! python3 -c "import psutil" 2>/dev/null; then
  echo "Installing psutil..."
  pip3 install psutil
  echo ""
fi

echo "1. Single benchmark with CSV output"
echo "-------------------------------------------------------------------"
echo "Command: ./benchmark_monitor.py elixir -a 50 -i 5 -E base -o csv"
echo ""
python3 "$SCRIPT_DIR/benchmark_monitor.py" elixir -a 50 -i 5 -E base -o csv
echo ""
echo "Output format: walltime_ms,max_memory_kb,avg_cpu_percent"
echo ""

echo "2. Single benchmark with JSON output"
echo "-------------------------------------------------------------------"
echo "Command: ./benchmark_monitor.py python -a 50 -i 5 -p 1 -o json"
echo ""
python3 "$SCRIPT_DIR/benchmark_monitor.py" python -a 50 -i 5 -p 1 -o json
echo ""

echo "3. Multiple trials comparison"
echo "-------------------------------------------------------------------"
echo "Running 3 trials each for Elixir base and Python..."
echo ""

# Create temp file for results
TEMP_CSV=$(mktemp)
echo "language,engine,trial,walltime_ms,max_memory_kb,avg_cpu_percent" > "$TEMP_CSV"

for i in 1 2 3; do
  echo "  Elixir trial $i/3..."
  RESULT=$(python3 "$SCRIPT_DIR/benchmark_monitor.py" elixir -a 50 -i 5 -E base -o csv)
  echo "elixir,base,$i,$RESULT" >> "$TEMP_CSV"
done

for i in 1 2 3; do
  echo "  Python trial $i/3..."
  RESULT=$(python3 "$SCRIPT_DIR/benchmark_monitor.py" python -a 50 -i 5 -p 1 -o csv)
  echo "python,single,$i,$RESULT" >> "$TEMP_CSV"
done

echo ""
echo "Results:"
cat "$TEMP_CSV"
echo ""

# Calculate averages
echo "Averages:"
python3 - "$TEMP_CSV" <<'PYTHON'
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

for key in sorted(data.keys()):
    metrics = data[key]
    avg_walltime = sum(metrics["walltime"]) / len(metrics["walltime"])
    avg_memory = sum(metrics["memory"]) / len(metrics["memory"])
    avg_cpu = sum(metrics["cpu"]) / len(metrics["cpu"])
    print(f"{key:15} | Walltime: {avg_walltime:7.1f} ms | Memory: {avg_memory:8.0f} KB | CPU: {avg_cpu:5.1f}%")
PYTHON

rm "$TEMP_CSV"

echo ""
echo "==================================================================="
echo "Demo complete!"
echo ""
echo "Next steps:"
echo "  - Run full benchmark suite: ./benchmark_trials_enhanced.sh"
echo "  - Read documentation: BENCHMARKING.md"
echo "  - Customize parameters for your use case"
echo "==================================================================="

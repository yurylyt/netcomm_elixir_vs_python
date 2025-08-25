#!/usr/bin/env bash
set -euo pipefail

AGENTS=300
ITERS=100
PROCS=8
TRIALS=10

echo "Elixir Base..."
for i in $(seq 1 "$TRIALS"); do
./run_sim.sh elixir -a $AGENTS -i $ITERS -E base
done

echo
echo "Elixir Proc..."
for i in $(seq 1 "$TRIALS"); do
./run_sim.sh elixir -a $AGENTS -i $ITERS -E proc
done

echo
echo "Python multi-process..."
for i in $(seq 1 "$TRIALS"); do
  ./run_sim.sh python -a $AGENTS -i $ITERS -p $PROCS
done

echo "Done"
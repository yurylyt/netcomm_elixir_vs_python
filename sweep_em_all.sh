#!/usr/bin/env bash

MIN_AGENTS=100
MAX_AGENTS=300
ITERS=100
PROCS=8

echo "=== ALL-PAIRS TOPOLOGY ==="
echo ""
echo "Running Elixir sweeps (all-pairs)..."
./sweep_sim.sh elixir $MIN_AGENTS $MAX_AGENTS -i $ITERS -E base -t all

echo "Running Elixir Proc sweeps (all-pairs)..."
./sweep_sim.sh elixir $MIN_AGENTS $MAX_AGENTS -i $ITERS -E proc -t all

echo
echo "Running Python sweeps multi process (all-pairs)..."
./sweep_sim.sh python $MIN_AGENTS $MAX_AGENTS -i $ITERS -p $PROCS -t all

echo ""
echo "=== RANDOM MATCHING TOPOLOGY (k=8) ==="
echo ""
echo "Running Elixir sweeps (random k=8)..."
./sweep_sim.sh elixir $MIN_AGENTS $MAX_AGENTS -i $ITERS -E base -t 8

echo
echo "Running Python sweeps multi process (random k=8)..."
./sweep_sim.sh python $MIN_AGENTS $MAX_AGENTS -i $ITERS -p $PROCS -t 8

echo ""
echo "Done"
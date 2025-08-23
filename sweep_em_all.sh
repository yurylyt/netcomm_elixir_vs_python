#!/usr/bin/env bash

MIN_AGENTS=201
MAX_AGENTS=300
ITERS=100
PROCS=4

echo "Running Elixir sweeps..."
./sweep_sim.sh elixir $MIN_AGENTS $MAX_AGENTS -i $ITERS

echo
echo "Running Python sweeps multi process..."
./sweep_sim.sh python $MIN_AGENTS $MAX_AGENTS -i $ITERS -p $PROCS

# echo
# echo "Running Python sweeps single process..."
# ./sweep_sim.sh python $MAX_AGENTS -i $ITERS -p 1

echo "Done"
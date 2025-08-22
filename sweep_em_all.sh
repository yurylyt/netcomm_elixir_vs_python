#!/usr/bin/env bash

MAX_AGENTS=200
ITERS=100
PROCS=4

echo "Running Elixir sweeps..."
./sweep_sim.sh elixir $MAX_AGENTS -i $ITERS

echo
echo "Running Python sweeps multi process..."
./sweep_sim.sh python $MAX_AGENTS -i $ITERS -p $PROCS

echo
echo "Running Python sweeps single process..."
./sweep_sim.sh python $MAX_AGENTS -i $ITERS -p 1

echo "Done"
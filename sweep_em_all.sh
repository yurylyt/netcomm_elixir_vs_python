#!/usr/bin/env bash

MIN_AGENTS=201
MAX_AGENTS=300
ITERS=100
PROCS=8

echo "Running Elixir sweeps..."
./sweep_sim.sh elixir $MIN_AGENTS $MAX_AGENTS -i $ITERS -E base

echo "Running Elixir Proc sweeps..."
./sweep_sim.sh elixir $MIN_AGENTS $MAX_AGENTS -i $ITERS -E proc

echo
echo "Running Python sweeps multi process..."
./sweep_sim.sh python $MIN_AGENTS $MAX_AGENTS -i $ITERS -p $PROCS

echo "Done"
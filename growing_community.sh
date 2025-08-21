#!/usr/bin/env bash

MIN_COMM_SIZE=2
MAX_COMM_SIZE=10

ITERS=10
SEED=42
CHUNK_SIZE=256
NUM_PROCS=${1:-1}

run_simulation() {
    local language=$1
    echo "$language"
    for i in $(seq "$MIN_COMM_SIZE" "$MAX_COMM_SIZE"); do
        ./run_sim.sh "$language" --agents "$i" --iterations "$ITERS" --seed "$SEED" --chunk-size "$CHUNK_SIZE" --procs "$NUM_PROCS"
    done
}

echo "Community size [$MIN_COMM_SIZE..$MAX_COMM_SIZE]"
run_simulation "python"
echo
run_simulation "elixir"
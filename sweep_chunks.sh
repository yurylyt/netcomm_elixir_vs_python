#!/usr/bin/env bash

COMM_SIZE=200
MIN_CHUNK_SIZE=1
MAX_CHUNK_SIZE=1024

ITERS=100
SEED=42
NUM_PROCS=${1:-1}

run_simulation() {
    local language=$1
    echo "$language"
    for i in $(seq "$MIN_CHUNK_SIZE" "$MAX_CHUNK_SIZE"); do
        ./run_sim.sh "$language" --agents "$COMM_SIZE" --iterations "$ITERS" --seed "$SEED" --chunk-size "$i" --procs "$NUM_PROCS"
    done
}

echo "Chunk size [$MIN_CHUNK_SIZE..$MAX_CHUNK_SIZE]"
# run_simulation "python"
echo
run_simulation "elixir"
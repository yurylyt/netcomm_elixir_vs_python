#!/usr/bin/env bash
set -euo pipefail

# Run the simulation in a given language implementation.
# Usage: ./run_sim.sh <language: elixir|python> <agents> <iterations> [seed]

usage() {
  echo "Usage: $0 <language: elixir|python> <agents> <iterations> [seed]" >&2
  exit 1
}

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  usage
fi

LANGUAGE="$1"
AGENTS="$2"
ITERS="$3"
SEED="${4:-42}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate numeric parameters
if ! [[ "$AGENTS" =~ ^[0-9]+$ ]] || ! [[ "$ITERS" =~ ^[0-9]+$ ]] || ! [[ "$SEED" =~ ^[0-9]+$ ]]; then
  echo "Error: agents, iterations, and seed must be integers." >&2
  exit 1
fi

case "$LANGUAGE" in
  elixir)
    if ! command -v mix >/dev/null 2>&1; then
      echo "Error: mix (Elixir) not found in PATH." >&2
      exit 1
    fi


    ELIXIR_DIR="$SCRIPT_DIR/elixir"
    if [ ! -d "$ELIXIR_DIR" ]; then
      echo "Error: Elixir project directory not found at $ELIXIR_DIR" >&2
      exit 1
    fi

    (
      cd "$ELIXIR_DIR"
      MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(${AGENTS}, ${ITERS}, ${SEED}))"
    )
    ;;

  python)
    echo "Error: Python implementation not available yet." >&2
    exit 2
    ;;

  *)
    echo "Error: Unknown language '$LANGUAGE'. Use 'elixir' or 'python'." >&2
    exit 1
    ;;
esac


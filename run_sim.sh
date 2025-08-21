#!/usr/bin/env bash
set -euo pipefail

# Run the simulation in a given language implementation.
# Usage (language as positional arg):
#   ./run_sim.sh elixir --agents 2000 --iterations 10 [--seed 42] [--chunk-size 256]
# Short forms: -a, -i, -s, -c

usage() {
  cat >&2 <<USAGE
Usage: $0 <language: elixir|python> --agents N --iterations N [--seed N] [--chunk-size N]
  -a, --agents        Community size (positive integer)
  -i, --iterations    Number of iterations/ticks (non-negative integer)
  -s, --seed          RNG seed (default: 42)
  -c, --chunk-size    Batch size for Elixir async processing (default: 256)
  -h, --help          Show this help
USAGE
  exit 1
}

LANGUAGE=""
AGENTS=""
ITERS=""
SEED=42
CHUNK_SIZE=256

# Allow language as the first positional argument if provided
if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
  LANGUAGE="$1"
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--agents)
      AGENTS="${2:-}"; shift 2 ;;
    -i|--iterations|--iters)
      ITERS="${2:-}"; shift 2 ;;
    -s|--seed)
      SEED="${2:-}"; shift 2 ;;
    -c|--chunk-size)
      CHUNK_SIZE="${2:-}"; shift 2 ;;
    -h|--help)
      usage ;;
    --)
      shift; break ;;
    *)
      echo "Unknown option: $1" >&2; usage ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate numeric parameters
if [ -z "$LANGUAGE" ] || [ -z "$AGENTS" ] || [ -z "$ITERS" ]; then
  echo "Error: language (positional), --agents, and --iterations are required." >&2
  usage
fi

if ! [[ "$AGENTS" =~ ^[1-9][0-9]*$ ]] || ! [[ "$ITERS" =~ ^[0-9]+$ ]] || ! [[ "$SEED" =~ ^[0-9]+$ ]] || ! [[ "$CHUNK_SIZE" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: agents, iterations, seed, and chunk_size must be positive integers." >&2
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
      MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(${AGENTS}, ${ITERS}, ${SEED}, ${CHUNK_SIZE}))"
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

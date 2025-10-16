#!/usr/bin/env bash
set -euo pipefail

# Sweep simulation sizes from MIN..MAX for a given language implementation.
# Usage: ./sweep_sim.sh <language: elixir|python> <min_agents> <max_agents> --iterations N [--seed N] [--chunk-size N] [--engine base|proc] [--procs N] [--topology all|N]

usage() {
  cat >&2 <<USAGE
Usage: $0 <language: elixir|python> <min_agents> <max_agents> --iterations N [--seed N] [--chunk-size N] [--engine base|proc] [--procs N] [--topology all|N]
  -i, --iterations    Number of iterations/ticks (non-negative integer)
  -s, --seed          RNG seed (default: 42)
  -c, --chunk-size    Batch size (Elixir async / Python per-task pairs) (default: 256)
  -E, --engine        Elixir: choose implementation engine: 'base' or 'proc' (default: base)
  -p, --procs         Python: number of worker processes (default: 1)
  -t, --topology      Topology: 'all' for all-pairs or integer k (1..n-1) for random matching (default: all)
  -h, --help          Show this help
Outputs: one line per run containing only elapsed milliseconds.
USAGE
  exit 1
}

LANGUAGE=""
MIN_AGENTS=""
MAX_AGENTS=""
ITERS=""
SEED=42
CHUNK_SIZE=256
PROCS=1
ENGINE="base"
TOPOLOGY="all"

# Positional args
if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
  LANGUAGE="$1"; shift
fi
if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
  MIN_AGENTS="$1"; shift
fi
if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
  MAX_AGENTS="$1"; shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -i|--iterations|--iters) ITERS="${2:-}"; shift 2 ;;
    -s|--seed) SEED="${2:-}"; shift 2 ;;
    -c|--chunk-size) CHUNK_SIZE="${2:-}"; shift 2 ;;
    -E|--engine) ENGINE="${2:-}"; shift 2 ;;
    -p|--procs) PROCS="${2:-}"; shift 2 ;;
    -t|--topology) TOPOLOGY="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    --) shift; break ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$LANGUAGE" ] || [ -z "$MIN_AGENTS" ] || [ -z "$MAX_AGENTS" ] || [ -z "$ITERS" ]; then
  echo "Error: language, min_agents and max_agents (positional), and --iterations are required." >&2
  usage
fi

if ! [[ "$MIN_AGENTS" =~ ^[1-9][0-9]*$ ]] || ! [[ "$MAX_AGENTS" =~ ^[1-9][0-9]*$ ]] || ! [[ "$ITERS" =~ ^[0-9]+$ ]] || ! [[ "$SEED" =~ ^[0-9]+$ ]] || ! [[ "$CHUNK_SIZE" =~ ^[1-9][0-9]*$ ]] || ! [[ "$PROCS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: min_agents, max_agents, iterations, seed, chunk_size, and procs must be positive integers." >&2
  exit 1
fi

if [ "$MIN_AGENTS" -lt 2 ] || [ "$MAX_AGENTS" -lt "$MIN_AGENTS" ]; then
  echo "Error: require min_agents >= 2 and max_agents >= min_agents." >&2
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
      # Convert topology to Elixir format
      if [ "$TOPOLOGY" = "all" ]; then
        TOPO_ARG=":all"
      else
        TOPO_ARG="$TOPOLOGY"
      fi
      case "$ENGINE" in
        base)
          MIX_ENV=prod mix run -e "MiniSim.sweep(${MIN_AGENTS}, ${MAX_AGENTS}, ${ITERS}, ${SEED}, ${CHUNK_SIZE}, ${TOPO_ARG})" ;;
        proc)
          MIX_ENV=prod mix run -e "MiniSim.Proc.sweep(${MIN_AGENTS}, ${MAX_AGENTS}, ${ITERS}, ${SEED}, ${CHUNK_SIZE})" ;;
        *)
          echo "Error: Unknown engine '$ENGINE'. Use 'base' or 'proc'." >&2; exit 1 ;;
      esac
    )
    ;;
  python)
    if ! command -v python3 >/dev/null 2>&1; then
      echo "Error: python3 not found in PATH." >&2
      exit 1
    fi
    PY_MAIN="$SCRIPT_DIR/python/main.py"
    if [ ! -f "$PY_MAIN" ]; then
      echo "Error: Python CLI not found at $PY_MAIN" >&2
      exit 1
    fi
    python3 "$PY_MAIN" \
      --iterations "$ITERS" \
      --seed "$SEED" \
      --chunk-size "$CHUNK_SIZE" \
      --procs "$PROCS" \
      --topology "$TOPOLOGY" \
      --sweep-from "$MIN_AGENTS" \
      --sweep-to "$MAX_AGENTS"
    ;;
  *)
    echo "Error: Unknown language '$LANGUAGE'. Use 'elixir' or 'python'." >&2
    exit 1
    ;;
esac

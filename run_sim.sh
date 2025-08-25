#!/usr/bin/env bash
set -euo pipefail

# Run the simulation in a given language implementation.
# Usage (language as positional arg):
#   ./run_sim.sh elixir --agents 2000 --iterations 10 [--seed 42] [--chunk-size 256]
# Short forms: -a, -i, -s, -c

usage() {
  cat >&2 <<USAGE
Usage: $0 <language: elixir|python> --agents N --iterations N [--seed N] [--chunk-size N] [--engine base|proc] [--procs N]
  -a, --agents        Community size (positive integer)
  -i, --iterations    Number of iterations/ticks (non-negative integer)
  -s, --seed          RNG seed (default: 42)
  -c, --chunk-size    Batch size for Elixir async processing (default: 256)
  -E, --engine        Elixir: choose implementation engine: 'base' or 'proc' (default: base)
  -p, --procs         Python: number of worker processes (default: 1)
  -h, --help          Show this help
USAGE
  exit 1
}

LANGUAGE=""
AGENTS=""
ITERS=""
SEED=42
CHUNK_SIZE=256
PROCS=1
ENGINE="base"

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
    -E|--engine)
      ENGINE="${2:-}"; shift 2 ;;
    -p|--procs)
      PROCS="${2:-}"; shift 2 ;;
    -h|--help)
      usage ;;
    --)
      shift; break ;;
    *)
      echo "Unknown option: $1" >&2; usage ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Return epoch milliseconds (prefers python3, falls back to seconds)
epoch_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

# Validate numeric parameters
if [ -z "$LANGUAGE" ] || [ -z "$AGENTS" ] || [ -z "$ITERS" ]; then
  echo "Error: language (positional), --agents, and --iterations are required." >&2
  usage
fi

if ! [[ "$AGENTS" =~ ^[1-9][0-9]*$ ]] || ! [[ "$ITERS" =~ ^[0-9]+$ ]] || ! [[ "$SEED" =~ ^[0-9]+$ ]] || ! [[ "$CHUNK_SIZE" =~ ^[1-9][0-9]*$ ]] || ! [[ "$PROCS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: agents, iterations, seed, chunk_size, and procs must be positive integers." >&2
  exit 1
fi

start_ms=$(epoch_ms)
cmd_status=0

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
      case "$ENGINE" in
        base)
          MIX_ENV=prod mix run -e "IO.inspect(MiniSim.run(${AGENTS}, ${ITERS}, ${SEED}, ${CHUNK_SIZE}))" > /dev/null ;;
        proc)
          MIX_ENV=prod mix run -e "IO.inspect(MiniSim.Proc.run(${AGENTS}, ${ITERS}, ${SEED}, ${CHUNK_SIZE}))" > /dev/null ;;
        *)
          echo "Error: Unknown engine '$ENGINE'. Use 'base' or 'proc'." >&2; exit 1 ;;
      esac
    )
    cmd_status=$?
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
      --agents "$AGENTS" \
      --iterations "$ITERS" \
      --seed "$SEED" \
      --chunk-size "$CHUNK_SIZE" \
      --procs "$PROCS" > /dev/null
    cmd_status=$?
    ;;

  *)
    echo "Error: Unknown language '$LANGUAGE'. Use 'elixir' or 'python'." >&2
    exit 1
    ;;
esac

end_ms=$(epoch_ms)
elapsed_ms=$(( end_ms - start_ms ))

echo "${elapsed_ms}"

exit ${cmd_status}

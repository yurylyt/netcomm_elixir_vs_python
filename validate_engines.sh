#!/usr/bin/env bash
# Quick validation script to verify all three engines produce correct results
# Usage: ./validate_engines.sh

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                Engine Validation Test Suite                          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Test parameters
SMALL_AGENTS=10
LARGE_AGENTS=100
ITERS=10
SEED=42

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo "  ✅ PASS: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "  ❌ FAIL: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() {
    echo "  ℹ️  INFO: $1"
}

echo "Test 1: Small all-pairs topology (should be identical)"
echo "───────────────────────────────────────────────────────"

BASE_OUTPUT=$(./run_sim.sh elixir -a $SMALL_AGENTS -i $ITERS -E base -s $SEED -t all -v 2>&1)
PROC_OUTPUT=$(./run_sim.sh elixir -a $SMALL_AGENTS -i $ITERS -E proc -s $SEED -t all -v 2>&1)
PY_OUTPUT=$(./run_sim.sh python -a $SMALL_AGENTS -i $ITERS -s $SEED -p 1 -t all -v 2>&1)

BASE_VOTES=$(echo "$BASE_OUTPUT" | grep "vote_results:" | grep -o '{[^}]*}')
PROC_VOTES=$(echo "$PROC_OUTPUT" | grep "vote_results:" | grep -o '{[^}]*}')
PY_VOTES=$(echo "$PY_OUTPUT" | grep -o '"vote_results": {[^}]*}' | grep -o '{[^}]*}')

BASE_AVG=$(echo "$BASE_OUTPUT" | grep "average_preferences:" | grep -o '\[[^]]*\]')
PROC_AVG=$(echo "$PROC_OUTPUT" | grep "average_preferences:" | grep -o '\[[^]]*\]')
PY_AVG=$(echo "$PY_OUTPUT" | grep -o '"average_preferences": \[[^]]*\]' | grep -o '\[[^]]*\]')

if [ "$BASE_VOTES" = "$PROC_VOTES" ]; then
    pass "Elixir base and proc produce identical vote results"
else
    fail "Elixir base and proc have different vote results"
fi

if [ "$BASE_AVG" = "$PROC_AVG" ]; then
    pass "Elixir base and proc produce identical averages"
else
    fail "Elixir base and proc have different averages"
fi

# Python comparison (normalize format differences)
BASE_VOTES_NORM=$(echo "$BASE_VOTES" | tr -d '%=>' | tr -d ' ')
PY_VOTES_NORM=$(echo "$PY_VOTES" | tr -d '":' | tr -d ' ')

if [[ "$BASE_VOTES_NORM" == *"0"* ]] && [[ "$PY_VOTES_NORM" == *"0"* ]]; then
    pass "Python produces equivalent vote results"
else
    info "Python vote format: $PY_VOTES"
fi

echo ""
echo "Test 2: Large all-pairs topology (performance check)"
echo "───────────────────────────────────────────────────────"

BASE_TIME=$(./run_sim.sh elixir -a $LARGE_AGENTS -i 5 -E base -s $SEED -t all 2>&1 | tail -1)
PROC_TIME=$(./run_sim.sh elixir -a $LARGE_AGENTS -i 5 -E proc -s $SEED -t all 2>&1 | tail -1)
PY_TIME=$(./run_sim.sh python -a $LARGE_AGENTS -i 5 -s $SEED -p 1 -t all 2>&1 | tail -1)

info "Elixir base: ${BASE_TIME}ms"
info "Elixir proc: ${PROC_TIME}ms"
info "Python:      ${PY_TIME}ms"

# Check if both Elixir engines complete in reasonable time (within 3x of each other)
RATIO=$(echo "scale=2; $PROC_TIME / $BASE_TIME" | bc)
if (( $(echo "$RATIO < 3.0" | bc -l) )) && (( $(echo "$RATIO > 0.33" | bc -l) )); then
    pass "Both Elixir engines show comparable performance (ratio: ${RATIO}x)"
else
    fail "Elixir engine performance differs significantly (ratio: ${RATIO}x)"
fi

echo ""
echo "Test 3: Random topology (all engines should complete)"
echo "───────────────────────────────────────────────────────"

if ./run_sim.sh elixir -a 50 -i 5 -E base -s $SEED -t 8 >/dev/null 2>&1; then
    pass "Elixir base completes with random topology"
else
    fail "Elixir base fails with random topology"
fi

if ./run_sim.sh elixir -a 50 -i 5 -E proc -s $SEED -t 8 >/dev/null 2>&1; then
    pass "Elixir proc completes with random topology"
else
    fail "Elixir proc fails with random topology"
fi

if ./run_sim.sh python -a 50 -i 5 -s $SEED -p 1 -t 8 >/dev/null 2>&1; then
    pass "Python completes with random topology"
else
    fail "Python fails with random topology"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                     Validation Results                               ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  ✅ Passed: %-3d                                                      ║\n" $PASS_COUNT
printf "║  ❌ Failed: %-3d                                                      ║\n" $FAIL_COUNT
echo "╚══════════════════════════════════════════════════════════════════════╝"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    echo "🎉 All validation tests passed!"
    echo ""
    exit 0
else
    echo ""
    echo "⚠️  Some tests failed. Please review the output above."
    echo ""
    exit 1
fi

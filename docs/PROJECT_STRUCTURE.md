# Project Structure

## Overview

This document describes the organization of the netcomm_elixir_vs_python repository.

## Directory Structure

```
.
├── README.md                    # Main project documentation
│
├── elixir/                      # Elixir implementation (base + proc engines)
├── python/                      # Python implementation
│
├── scripts/                     # All executable scripts
│   ├── run_sim.sh               # Single simulation runner
│   ├── sweep_*.sh               # Various sweep scripts
│   ├── benchmark_*.sh/py        # Benchmark tools
│   └── validate_engines.sh      # Validation test suite
│
├── tests/                       # Integration tests (*.exs)
├── docs/                        # Documentation (*.md)
├── benchmark_analysis/          # Benchmark results and analysis
└── paper/                       # Academic papers
```

## Running Scripts

All scripts are now in the `scripts/` directory. Run them from the project root:

```bash
# From project root
./scripts/run_sim.sh elixir -a 100 -i 10

# Or with full path
cd /path/to/project
./scripts/benchmark_trials_enhanced.sh -a 300 -i 10 -t 5
```

## Documentation Organization

All documentation is in the `docs/` directory:

- **BENCHMARKING.md** - Comprehensive benchmarking guide with tools and methodology
- **BENCHMARK_QUICKSTART.md** - Quick start guide for running benchmarks
- **TOPOLOGY.md** - Network topology concepts and implementation
- **TOPOLOGY_BENCHMARKING.md** - Comparing performance across topologies
- **VALIDATION.md** - Correctness validation and test results
- **PROJECT_STRUCTURE.md** - This file

## Recent Changes

### Removed Files

Historic refactoring documentation has been removed:
- ~~BUGFIX_HANGING_BENCHMARK.md~~ - Fixed issue, documentation no longer needed
- ~~PROC_ENGINE_TOPOLOGY_LIMITATION.md~~ - Feature implemented, doc obsolete
- ~~TOPOLOGY_SUPPORT_IMPLEMENTATION.md~~ - Implementation complete, archived

### File Relocations

- All shell scripts (`*.sh`) → `scripts/`
- `benchmark_monitor.py` → `scripts/`
- All Elixir test files (`test_*.exs`) → `tests/`
- All documentation (`*.md` except README) → `docs/`
- `benchmark_results.csv` → `benchmark_analysis/`

## Usage Notes

### Scripts call each other correctly

Scripts in `scripts/` have been updated to use relative paths within the directory:
- `sweep_em_all.sh` calls `sweep_sim.sh`
- `sweep_chunks.sh` calls `run_sim.sh`
- `validate_engines.sh` calls `run_sim.sh`

### Documentation references are updated

All documentation in `docs/` uses correct relative paths:
- Examples use `../scripts/run_sim.sh` format
- Links to other docs use relative paths

### Backward Compatibility

To maintain compatibility with existing workflows, you can:

1. **Create aliases** in your shell:
   ```bash
   alias run_sim='./scripts/run_sim.sh'
   alias benchmark='./scripts/benchmark_trials_enhanced.sh'
   ```

2. **Add scripts to PATH**:
   ```bash
   export PATH="$PATH:/path/to/project/scripts"
   ```

3. **Use make targets** (future enhancement):
   ```bash
   make bench    # runs benchmark_trials_enhanced.sh
   make validate # runs validate_engines.sh
   ```

## Contributing

When adding new files:
- Scripts → `scripts/`
- Documentation → `docs/`
- Tests → `tests/` or language-specific test directories
- Benchmark data → `benchmark_analysis/`
- Keep root directory minimal and clean

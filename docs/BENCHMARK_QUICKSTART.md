# Enhanced Benchmarking - Quick Reference

## New Files Added

### Core Tools
- **`benchmark_monitor.py`** - Python-based resource monitor (requires psutil)
- **`benchmark_trials_enhanced.sh`** - Multi-trial runner with statistics

### Documentation & Examples
- **`BENCHMARKING.md`** - Complete benchmarking guide
- **`demo_benchmark.sh`** - Quick demonstration script

### Updates
- **`python/requirements.txt`** - Added psutil dependency
- **`README.md`** - Updated with benchmarking overview

## Quick Start

```bash
# 1. Install dependencies
pip install -r python/requirements.txt

# 2. Run a quick demo
./demo_benchmark.sh

# 3. Run comprehensive benchmarks
../scripts/benchmark_trials_enhanced.sh -a 300 -i 10 -t 5
```

## Metrics Measured

| Metric | Description | Unit | Interpretation |
|--------|-------------|------|----------------|
| **Walltime** | Total elapsed time | milliseconds | Lower is better; user-perceived performance |
| **Max Memory** | Peak memory usage (RSS) | kilobytes | Lower is better; physical RAM consumption |
| **Avg CPU** | Average CPU utilization | percent | >100% indicates multi-core usage |

## Usage Examples

### Single Run with Full Metrics

```bash
# Elixir base engine
../scripts/benchmark_monitor.py elixir -a 100 -i 10 -E base

# Elixir proc engine
../scripts/benchmark_monitor.py elixir -a 100 -i 10 -E proc

# Python single-process
../scripts/benchmark_monitor.py python -a 100 -i 10 -p 1

# Python multi-process (8 workers)
../scripts/benchmark_monitor.py python -a 100 -i 10 -p 8
```

**CSV Output:**
```
walltime_ms,max_memory_kb,avg_cpu_percent
1234,45678,125.50
```

**JSON Output:**
```bash
../scripts/benchmark_monitor.py elixir -a 100 -i 10 -E base -o json
# {"walltime_ms": 1234, "max_memory_kb": 45678, "avg_cpu_percent": 125.50}
```

### Multiple Trials with Statistics

```bash
# Default: 300 agents, 10 iterations, 5 trials
../scripts/benchmark_trials_enhanced.sh

# Custom configuration
../scripts/benchmark_trials_enhanced.sh -a 500 -i 20 -t 10 -p 8 -o results.csv
```

**Output:**
```
Configuration        Metric          Mean         Median       StdDev      
---------------------------------------------------------------------------
elixir-base          Walltime (ms)       1234.5       1230.0         45.2
                     Memory (KB)        45678.0      45500.0        234.5
                     CPU (%)              125.5        124.0          5.3
```

## Comparison with Existing Tools

| Script | Walltime | Memory | CPU | Trials | Use Case |
|--------|----------|--------|-----|--------|----------|
| `run_sim.sh` | ✅ | ❌ | ❌ | No | Quick single runs |
| `sweep_sim.sh` | ✅ | ❌ | ❌ | No | Community size sweeps |
| **`benchmark_monitor.py`** ✨ | ✅ | ✅ | ✅ | No | Single run with full metrics |
| **`benchmark_trials_enhanced.sh`** ✨ | ✅ | ✅ | ✅ | Yes | Multiple trials with full metrics |

## Common Workflows

### 1. Quick Performance Check
```bash
../scripts/benchmark_monitor.py elixir -a 100 -i 10 -E base
```

### 2. Statistical Analysis (Publication)
```bash
../scripts/benchmark_trials_enhanced.sh -a 1000 -i 50 -t 10 -o paper_results.csv
```

### 3. Comparing Configurations
```bash
# Test different chunk sizes
for chunk in 64 128 256 512; do
  echo "Chunk size: $chunk"
  ../scripts/benchmark_monitor.py elixir -a 500 -i 20 -c $chunk -E base
done
```

### 4. Memory Profiling
```bash
# Find memory usage pattern across community sizes
for agents in 100 200 500 1000 2000; do
  echo -n "$agents,"
  ../scripts/benchmark_monitor.py elixir -a $agents -i 10 -E base -o csv
done > memory_profile.csv
```

## Understanding CPU Percentages

CPU percentage can exceed 100% when using multiple cores:

- **100%** = Fully utilizing 1 CPU core
- **200%** = Fully utilizing 2 CPU cores  
- **800%** = Fully utilizing 8 CPU cores

**Example interpretations:**
- Elixir base: `125%` → Good parallelism (1.25 cores on average)
- Python single: `98%` → Single-threaded (as expected)
- Python multi (8 procs): `543%` → Using ~5.4 cores effectively

## Data Analysis

### Load Results in Python
```python
import pandas as pd

df = pd.read_csv('benchmark_results.csv')
grouped = df.groupby(['language', 'engine'])

# Summary statistics
print(grouped.agg({
    'walltime_ms': ['mean', 'std', 'min', 'max'],
    'max_memory_kb': ['mean', 'std'],
    'avg_cpu_percent': ['mean', 'std']
}))
```

### Plot Comparison
```python
import matplotlib.pyplot as plt

grouped['walltime_ms'].mean().plot(kind='bar')
plt.title('Average Walltime by Configuration')
plt.ylabel('Walltime (ms)')
plt.show()
```

## Troubleshooting

### psutil not installed
```bash
pip install psutil
# or
pip install -r python/requirements.txt
```

### High variance in results
- Close other applications
- Disable CPU frequency scaling
- Increase number of trials
- Run during off-peak hours

### Process monitoring issues
The Python monitor is more reliable than the shell version. If you encounter issues:
```bash
# Use Python monitor (recommended)
../scripts/benchmark_monitor.py elixir -a 100 -i 10

# Fallback to shell monitor
./benchmark.sh elixir -a 100 -i 10
```

## Next Steps

1. **Run the demo**: `./demo_benchmark.sh`
2. **Read full docs**: See `BENCHMARKING.md` for detailed information
3. **Run your benchmarks**: Use `benchmark_trials_enhanced.sh` for comprehensive testing
4. **Analyze results**: Import CSV into your analysis tool of choice

## Support

For questions or issues:
- Check `BENCHMARKING.md` for detailed documentation
- Review examples in `demo_benchmark.sh`
- Ensure psutil is installed: `pip install psutil`

# Enhanced Benchmarking Guide

This guide describes the enhanced benchmarking tools that measure **walltime**, **memory footprint**, and **CPU usage** for the Elixir and Python implementations.

## Overview

The enhanced benchmarking suite provides two complementary tools:

1. **`benchmark_monitor.py`** - Python-based monitoring using `psutil` for accurate metrics
2. **`benchmark_trials_enhanced.sh`** - Multi-trial runner with statistical analysis

## Quick Start

### Process monitoring issues
If the monitor fails to capture metrics:
```bash
# Ensure psutil is installed
pip install psutil

# Try with verbose output to see any errors
./benchmark_monitor.py elixir -a 100 -i 10 -v
```

### Single Benchmark Run

```bash
# Using Python monitor for accurate metrics
./benchmark_monitor.py elixir -a 100 -i 10 -E base
```

### Multiple Trials with Statistics

```bash
# Run 5 trials of each configuration (Elixir base, Elixir proc, Python single, Python multi)
./benchmark_trials_enhanced.sh -a 300 -i 10 -t 5

# Custom configuration
./benchmark_trials_enhanced.sh -a 500 -i 20 -t 10 -p 8 -o results.csv
```

## Tool Reference

### `benchmark_monitor.py` - Python-based Monitor

**Most accurate** resource monitoring using the `psutil` library.

**Usage:**
```bash
./benchmark_monitor.py <language> [OPTIONS]
```

**Options:**
- `-a, --agents N` - Community size (required)
- `-i, --iterations N` - Number of iterations (required)
- `-s, --seed N` - RNG seed (default: 42)
- `-c, --chunk-size N` - Batch size (default: 256)
- `-E, --engine ENGINE` - Elixir engine: `base` or `proc` (default: base)
- `-p, --procs N` - Python worker processes (default: 1)
- `-o, --output FORMAT` - Output format: `csv` or `json` (default: csv)
- `-v, --verbose` - Print program output

**Examples:**
```bash
# Elixir base engine
./benchmark_monitor.py elixir -a 100 -i 10 -E base

# Elixir proc engine
./benchmark_monitor.py elixir -a 100 -i 10 -E proc

# Python single-process
./benchmark_monitor.py python -a 100 -i 10 -p 1

# Python multi-process (8 workers)
./benchmark_monitor.py python -a 100 -i 10 -p 8

# JSON output format
./benchmark_monitor.py elixir -a 100 -i 10 -E base -o json
```

**Output Format (CSV):**
```
walltime_ms,max_memory_kb,avg_cpu_percent
1234,45678,125.50
```

**Output Format (JSON):**
```json
{"walltime_ms": 1234, "max_memory_kb": 45678, "avg_cpu_percent": 125.50}
```

### `benchmark_trials_enhanced.sh` - Multi-trial Runner

Runs multiple trials for each configuration and outputs statistical summary.

**Usage:**
```bash
./benchmark_trials_enhanced.sh [OPTIONS]
```

**Options:**
- `-a, --agents N` - Community size (default: 300)
- `-i, --iterations N` - Number of iterations (default: 10)
- `-t, --trials N` - Number of trials per configuration (default: 5)
- `-p, --procs N` - Python worker processes (default: 8)
- `-c, --chunk-size N` - Batch size (default: 256)
- `-o, --output FILE` - Output CSV file (default: benchmark_results.csv)

**Example:**
```bash
# Run 10 trials with 500 agents, 20 iterations
./benchmark_trials_enhanced.sh -a 500 -i 20 -t 10 -p 8 -o my_results.csv
```

**Output:**
The script creates a CSV file with all trial results and prints a summary table:

```
Configuration        Metric          Mean         Median       StdDev      
---------------------------------------------------------------------------
elixir-base          Walltime (ms)       1234.5       1230.0         45.2
                     Memory (KB)        45678.0      45500.0        234.5
                     CPU (%)              125.5        124.0          5.3

elixir-proc          Walltime (ms)       1456.7       1450.0         52.1
                     Memory (KB)        56789.0      56700.0        345.6
                     CPU (%)              135.2        134.5          6.7

python-single        Walltime (ms)       2345.6       2340.0         78.9
                     Memory (KB)        34567.0      34500.0        123.4
                     CPU (%)               98.7         98.5          2.1

python-multi         Walltime (ms)        987.6        985.0         34.2
                     Memory (KB)        98765.0      98700.0        456.7
                     CPU (%)              543.2        540.0         12.3
```

## Metrics Explained

### Walltime (ms)
Total elapsed time from start to finish, measured in milliseconds. This is "wall clock" time and includes:
- CPU computation time
- I/O wait time
- Time waiting for other processes
- Scheduler delays

**Interpretation:**
- Lower is better
- Represents user-perceived performance
- Can vary due to system load

### Max Memory (KB)
Peak resident set size (RSS) during execution, measured in kilobytes. This represents the maximum amount of physical RAM used by the process.

**Interpretation:**
- Lower is better for memory-constrained environments
- Elixir may show higher values due to BEAM VM overhead
- Python multiprocessing creates separate process copies, increasing memory

### Average CPU (%)
Average CPU utilization across all cores during execution. Values > 100% indicate multi-core usage.

**Interpretation:**
- `100%` = fully utilizing one CPU core
- `200%` = fully utilizing two CPU cores
- `800%` = fully utilizing eight CPU cores
- Higher values indicate better parallelism (up to available cores)
- Elixir often achieves higher CPU utilization through lightweight processes

## CSV Output Format

The CSV file contains one row per trial with the following columns:

```csv
language,engine,trial,agents,iterations,chunk_size,procs,walltime_ms,max_memory_kb,avg_cpu_percent
elixir,base,1,300,10,256,1,1234,45678,125.50
elixir,base,2,300,10,256,1,1240,45690,126.20
elixir,proc,1,300,10,256,1,1456,56789,135.20
python,single,1,300,10,256,1,2345,34567,98.70
python,multi,1,300,10,256,8,987,98765,543.20
```

This format is easily imported into spreadsheet applications, data analysis tools, or plotting libraries.

## Data Analysis Examples

### Using Python/Pandas

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load results
df = pd.read_csv('benchmark_results.csv')

# Group by configuration
grouped = df.groupby(['language', 'engine'])

# Calculate statistics
stats = grouped.agg({
    'walltime_ms': ['mean', 'std', 'min', 'max'],
    'max_memory_kb': ['mean', 'std'],
    'avg_cpu_percent': ['mean', 'std']
})

print(stats)

# Plot walltime comparison
grouped['walltime_ms'].mean().plot(kind='bar')
plt.title('Average Walltime by Configuration')
plt.ylabel('Walltime (ms)')
plt.show()
```

### Using R

```r
library(tidyverse)

# Load results
df <- read_csv('benchmark_results.csv')

# Summary by configuration
df %>%
  group_by(language, engine) %>%
  summarise(
    mean_walltime = mean(walltime_ms),
    sd_walltime = sd(walltime_ms),
    mean_memory = mean(max_memory_kb),
    mean_cpu = mean(avg_cpu_percent)
  )

# Boxplot comparison
ggplot(df, aes(x=interaction(language, engine), y=walltime_ms)) +
  geom_boxplot() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
```

## Best Practices

### Statistical Rigor

1. **Multiple trials**: Run at least 5 trials per configuration (10+ for publication)
2. **Warmup**: Discard the first run to eliminate cold-start effects
3. **System state**: Close other applications to reduce interference
4. **CPU frequency**: Disable CPU frequency scaling for consistent results
5. **Background processes**: Minimize background activity

### Consistent Environment

```bash
# Disable CPU frequency scaling (Linux)
sudo cpupower frequency-set --governor performance

# Set CPU affinity (Linux)
taskset -c 0-7 ./benchmark_monitor.py elixir -a 100 -i 10

# Monitor system load
htop  # Keep an eye on system resources
```

### Comparing Configurations

When comparing different configurations:
- Use the **median** for central tendency (robust to outliers)
- Use **standard deviation** to assess consistency
- Plot distributions to identify bimodal patterns
- Check for statistical significance (t-test, ANOVA)

## Troubleshooting

### High variance in results

**Symptom:** Large standard deviations across trials

**Solutions:**
- Increase number of trials
- Check for background processes (Activity Monitor on macOS, htop on Linux)
- Disable CPU frequency scaling
- Run during off-peak hours
- Consider using a dedicated benchmarking machine

### Memory measurements seem low

**Symptom:** Memory usage lower than expected

**Possible causes:**
- `psutil` reports RSS (physical RAM), not virtual memory
- BEAM VM may allocate memory differently
- Garbage collection timing affects measurements

**Solutions:**
- Use longer-running simulations (more iterations)
- Check with system-specific tools (`/usr/bin/time -l` on macOS)

### CPU percentage > 100%

**This is normal!** CPU percentages can exceed 100% when using multiple cores:
- `150%` = using 1.5 cores
- `800%` = using 8 cores fully

### psutil not found

**Error:** `ImportError: No module named 'psutil'`

**Solution:**
```bash
pip install psutil

# Or with requirements.txt
pip install -r python/requirements.txt
```

## Integration with Existing Scripts

The enhanced benchmarking tools are complementary to existing scripts:

- **`run_sim.sh`** - Quick single runs (walltime only)
- **`sweep_sim.sh`** - Community size sweeps (walltime only)
- **`sweep_em_all.sh`** - Comprehensive sweep across all engines (walltime only)
- **`benchmark_monitor.py`** ✨ **NEW** - Single run with full metrics
- **`benchmark_trials_enhanced.sh`** ✨ **NEW** - Multiple trials with full metrics

You can continue using the original scripts for quick tests, and use the enhanced tools when you need detailed resource profiling.

## Example Workflow

Here's a complete workflow for benchmarking:

```bash
# 1. Install dependencies
pip install -r python/requirements.txt

# 2. Quick test to ensure everything works
./benchmark_monitor.py elixir -a 10 -i 5 -E base -v

# 3. Run comprehensive benchmarks
./benchmark_trials_enhanced.sh -a 300 -i 100 -t 10 -o results.csv

# 4. Analyze results
python3 <<EOF
import pandas as pd
df = pd.read_csv('results.csv')
print(df.groupby(['language', 'engine']).agg({
    'walltime_ms': ['mean', 'std'],
    'max_memory_kb': ['mean', 'std'],
    'avg_cpu_percent': ['mean', 'std']
}))
EOF
```

## Future Enhancements

Potential additions to the benchmarking suite:
- [ ] Profiling support (perf, flamegraphs)
- [ ] Network I/O metrics
- [ ] Garbage collection statistics
- [ ] Detailed process tree analysis
- [ ] Automated statistical testing (t-tests)
- [ ] HTML report generation
- [ ] Integration with visualization tools

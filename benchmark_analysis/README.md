# Benchmark Analysis Tools - Quick Start

This directory contains tools for analyzing and presenting benchmark results with proper statistical measures.

## Available Tools

### 1. `calculate_stats.py` - Statistical Analysis
Calculates median and 95% confidence intervals using bootstrap resampling.

```bash
# Basic usage
python calculate_stats.py benchmark_run_all_pairs.csv

# Save results to CSV
python calculate_stats.py benchmark_run_all_pairs.csv -o stats_output.csv

# Group by different columns
python calculate_stats.py input.csv -g language engine topology

# Adjust bootstrap samples
python calculate_stats.py input.csv -b 20000
```

**Output**: Console display + optional CSV file with statistics

### 2. `generate_tables.py` - LaTeX/Markdown Tables
Generates publication-ready tables from statistics CSV.

```bash
# LaTeX table (both full and compact)
python generate_tables.py stats_output.csv

# Specific format
python generate_tables.py stats_output.csv -f full      # Full LaTeX
python generate_tables.py stats_output.csv -f compact   # Compact LaTeX
python generate_tables.py stats_output.csv -f markdown  # Markdown table
python generate_tables.py stats_output.csv -f csv       # Simple CSV

# Save to file
python generate_tables.py stats_output.csv -o table.tex
```

**Output**: Formatted table ready for copy-paste into your paper

### 3. `plot_results.py` - Visualization
Generates publication-quality plots.

```bash
# Generate all plots
python plot_results.py stats_output.csv -o figures/

# Specific plot type
python plot_results.py stats_output.csv -t bar        # Bar plot with error bars
python plot_results.py stats_output.csv -t ci         # CI ranges
python plot_results.py stats_output.csv -t normalized # Normalized comparison
```

**Output**: PDF and PNG files in the figures directory

## Complete Workflow

```bash
# 1. Calculate statistics
python calculate_stats.py benchmark_run_all_pairs.csv -o stats.csv

# 2. Generate LaTeX tables
python generate_tables.py stats.csv -o tables.tex

# 3. Create figures
python plot_results.py stats.csv -o ../paper/2025_why_elixir/figures/

# 4. View results
cat stats.csv
```

## Output Examples

### Console Output (calculate_stats.py)
```
====================================================================================================
BENCHMARK STATISTICS: Median and 95% Confidence Intervals
====================================================================================================

language: elixir | engine: proc
----------------------------------------------------------------------------------------------------
Number of trials: 10

  Walltime (ms):
    Median:        19041.00
    95% CI:    [    18944.00,     19102.00]
    CI Width:        158.00
...
```

### LaTeX Table (generate_tables.py)
```latex
\begin{table}[htbp]
\centering
\caption{Performance Summary (Median ± 95\% CI Half-Width)}
...
```

### Markdown Table (generate_tables.py)
```markdown
| Language | Engine | Walltime (ms) | Memory (KB) | CPU (%) |
|----------|--------|---------------|-------------|---------|
| Elixir | proc | 19,041<br>[18,944–19,102] | ... | ... |
```

## For Your Paper

See `../PRESENTING_RESULTS.md` for detailed guidance on:
- Writing results sections
- Figure captions
- Methods description
- Best practices

## Requirements

Install required packages:
```bash
pip install pandas numpy matplotlib
```

## Files in This Directory

- `calculate_stats.py` - Statistical analysis tool
- `generate_tables.py` - Table generation tool  
- `plot_results.py` - Visualization tool
- `benchmark_run_*.csv` - Raw benchmark data
- `stats_*.csv` - Computed statistics (generated)
- `figures/` - Generated plots (created by plot_results.py)

## Tips

1. **Always calculate statistics first** before generating tables or plots
2. **Use consistent grouping** across all tools (-g flag)
3. **Save intermediate results** (-o flag) for reproducibility
4. **Generate both PDF and PNG** figures (automatic with plot_results.py)
5. **Check CI widths** - narrow widths indicate reliable measurements

## Common Issues

**Problem**: "ModuleNotFoundError: No module named 'pandas'"
**Solution**: `pip install pandas numpy matplotlib`

**Problem**: No plots displayed
**Solution**: Use `-o figures/` to save to files instead

**Problem**: Wrong columns in output
**Solution**: Check your input CSV has the expected column names

## Statistical Notes

- **Bootstrap sampling (10,000 iterations)** provides robust CI estimates
- **95% CI** means you're 95% confident the true median is in that range
- **Non-overlapping CIs** indicate statistically significant differences
- **Narrow CI widths** indicate low variability and good reproducibility

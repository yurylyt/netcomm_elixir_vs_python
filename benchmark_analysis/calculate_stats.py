#!/usr/bin/env python3
"""
Calculate median and 95% confidence intervals for benchmark metrics.

This script analyzes benchmark data from CSV files and calculates:
- Median values
- 95% confidence intervals using bootstrap method
for walltime, memory, and processor metrics.
"""

import pandas as pd
import numpy as np
from pathlib import Path
import argparse
from typing import Tuple


def bootstrap_ci(data: np.ndarray, n_bootstrap: int = 10000, confidence: float = 0.95) -> Tuple[float, float]:
    """
    Calculate confidence interval using bootstrap method.
    
    Args:
        data: Array of data points
        n_bootstrap: Number of bootstrap samples
        confidence: Confidence level (default 0.95 for 95% CI)
    
    Returns:
        Tuple of (lower_bound, upper_bound)
    """
    bootstrap_medians = []
    n = len(data)
    
    for _ in range(n_bootstrap):
        # Resample with replacement
        sample = np.random.choice(data, size=n, replace=True)
        bootstrap_medians.append(np.median(sample))
    
    # Calculate percentiles for confidence interval
    alpha = 1 - confidence
    lower_percentile = (alpha / 2) * 100
    upper_percentile = (1 - alpha / 2) * 100
    
    lower_bound = np.percentile(bootstrap_medians, lower_percentile)
    upper_bound = np.percentile(bootstrap_medians, upper_percentile)
    
    return lower_bound, upper_bound


def calculate_statistics(df: pd.DataFrame, group_by: list = None) -> pd.DataFrame:
    """
    Calculate median and 95% CI for metrics.
    
    Args:
        df: DataFrame with benchmark data
        group_by: List of columns to group by (e.g., ['language', 'engine', 'topology'])
    
    Returns:
        DataFrame with calculated statistics
    """
    metrics = {
        'walltime_ms': 'Walltime (ms)',
        'max_memory_kb': 'Memory (KB)',
        'avg_cpu_percent': 'CPU (%)'
    }
    
    if group_by is None:
        group_by = ['language', 'engine']
    
    # Filter for columns that exist in the dataframe
    available_group_by = [col for col in group_by if col in df.columns]
    available_metrics = {k: v for k, v in metrics.items() if k in df.columns}
    
    if not available_metrics:
        raise ValueError("No metrics columns found in the dataframe")
    
    results = []
    
    # Group data and calculate statistics
    if available_group_by:
        groups = df.groupby(available_group_by)
    else:
        groups = [(('all',), df)]
    
    for group_keys, group_data in groups:
        if not isinstance(group_keys, tuple):
            group_keys = (group_keys,)
        
        result = dict(zip(available_group_by, group_keys))
        result['n_trials'] = len(group_data)
        
        for metric_col, metric_name in available_metrics.items():
            data = group_data[metric_col].values
            
            if len(data) > 0:
                median = np.median(data)
                lower_ci, upper_ci = bootstrap_ci(data)
                
                result[f'{metric_name} - Median'] = median
                result[f'{metric_name} - 95% CI Lower'] = lower_ci
                result[f'{metric_name} - 95% CI Upper'] = upper_ci
                result[f'{metric_name} - CI Width'] = upper_ci - lower_ci
        
        results.append(result)
    
    return pd.DataFrame(results)


def format_output(stats_df: pd.DataFrame) -> str:
    """Format the statistics DataFrame for display."""
    output = []
    output.append("=" * 100)
    output.append("BENCHMARK STATISTICS: Median and 95% Confidence Intervals")
    output.append("=" * 100)
    output.append("")
    
    # Get grouping columns (exclude metrics and n_trials)
    metric_patterns = ['Median', 'CI Lower', 'CI Upper', 'CI Width']
    group_cols = [col for col in stats_df.columns 
                  if col != 'n_trials' and not any(pattern in col for pattern in metric_patterns)]
    
    for idx, row in stats_df.iterrows():
        # Print group identifier
        if group_cols:
            group_desc = " | ".join([f"{col}: {row[col]}" for col in group_cols])
            output.append(f"\n{group_desc}")
            output.append("-" * 100)
        
        output.append(f"Number of trials: {int(row['n_trials'])}")
        output.append("")
        
        # Find all unique metrics
        metrics_found = set()
        for col in stats_df.columns:
            if ' - Median' in col:
                metric_name = col.replace(' - Median', '')
                metrics_found.add(metric_name)
        
        for metric in sorted(metrics_found):
            median_col = f'{metric} - Median'
            lower_col = f'{metric} - 95% CI Lower'
            upper_col = f'{metric} - 95% CI Upper'
            width_col = f'{metric} - CI Width'
            
            if median_col in row:
                median = row[median_col]
                lower = row[lower_col]
                upper = row[upper_col]
                width = row[width_col]
                
                output.append(f"  {metric}:")
                output.append(f"    Median:    {median:12.2f}")
                output.append(f"    95% CI:    [{lower:12.2f}, {upper:12.2f}]")
                output.append(f"    CI Width:  {width:12.2f}")
                output.append("")
    
    output.append("=" * 100)
    return "\n".join(output)


def main():
    parser = argparse.ArgumentParser(
        description='Calculate median and 95% confidence intervals for benchmark metrics'
    )
    parser.add_argument(
        'csv_file',
        nargs='?',
        help='Path to the CSV file to analyze (default: benchmark_run_all_pairs.csv)'
    )
    parser.add_argument(
        '-g', '--group-by',
        nargs='+',
        default=['language', 'engine'],
        help='Columns to group by (default: language engine)'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output file for statistics (CSV format)'
    )
    parser.add_argument(
        '-b', '--bootstrap',
        type=int,
        default=10000,
        help='Number of bootstrap samples (default: 10000)'
    )
    
    args = parser.parse_args()
    
    # Determine input file
    if args.csv_file:
        csv_path = Path(args.csv_file)
    else:
        # Default to benchmark_run_all_pairs.csv in current directory or benchmark_analysis
        script_dir = Path(__file__).parent
        csv_path = script_dir / 'benchmark_run_all_pairs.csv'
        if not csv_path.exists():
            csv_path = Path('benchmark_run_all_pairs.csv')
    
    if not csv_path.exists():
        print(f"Error: CSV file not found: {csv_path}")
        print("\nAvailable CSV files in benchmark_analysis:")
        analysis_dir = Path(__file__).parent
        for f in analysis_dir.glob('*.csv'):
            print(f"  {f.name}")
        return 1
    
    # Load data
    print(f"Loading data from: {csv_path}")
    df = pd.read_csv(csv_path)
    print(f"Loaded {len(df)} rows")
    print(f"Columns: {', '.join(df.columns)}")
    print()
    
    # Calculate statistics
    print(f"Calculating statistics (bootstrap samples: {args.bootstrap})...")
    np.random.seed(42)  # For reproducibility
    stats_df = calculate_statistics(df, group_by=args.group_by)
    
    # Display results
    print(format_output(stats_df))
    
    # Save to file if requested
    if args.output:
        output_path = Path(args.output)
        stats_df.to_csv(output_path, index=False)
        print(f"\nStatistics saved to: {output_path}")
    
    return 0


if __name__ == '__main__':
    exit(main())

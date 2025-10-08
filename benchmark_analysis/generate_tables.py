#!/usr/bin/env python3
"""
Generate LaTeX tables from benchmark statistics CSV files.
"""

import pandas as pd
import argparse
from pathlib import Path


def format_ci(lower, upper, decimal_places=0):
    """Format confidence interval."""
    if decimal_places == 0:
        return f"[{lower:,.0f}--{upper:,.0f}]"
    else:
        return f"[{lower:.{decimal_places}f}--{upper:.{decimal_places}f}]"


def format_value_with_ci(median, lower, upper, decimal_places=0):
    """Format median with CI on separate line."""
    if decimal_places == 0:
        median_str = f"{median:,.0f}"
    else:
        median_str = f"{median:.{decimal_places}f}"
    
    ci_str = format_ci(lower, upper, decimal_places)
    return median_str, ci_str


def generate_full_table(stats_df: pd.DataFrame) -> str:
    """
    Generate LaTeX table with median on first line, CI on second line.
    """
    latex = []
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(r"\caption{Performance Metrics by Language and Engine Configuration}")
    latex.append(r"\label{tab:performance}")
    latex.append(r"\small")
    latex.append(r"\begin{tabular}{llrrr}")
    latex.append(r"\toprule")
    latex.append(r"Language & Engine & Walltime (ms) & Memory (KB) & CPU (\%) \\")
    latex.append(r"         &        & Median [95\% CI] & Median [95\% CI] & Median [95\% CI] \\")
    latex.append(r"\midrule")
    
    for idx, row in stats_df.iterrows():
        lang = row.get('language', 'N/A').capitalize()
        engine = row.get('engine', 'N/A')
        
        # Walltime
        wt_med, wt_ci = format_value_with_ci(
            row['Walltime (ms) - Median'],
            row['Walltime (ms) - 95% CI Lower'],
            row['Walltime (ms) - 95% CI Upper'],
            decimal_places=0
        )
        
        # Memory
        mem_med, mem_ci = format_value_with_ci(
            row['Memory (KB) - Median'],
            row['Memory (KB) - 95% CI Lower'],
            row['Memory (KB) - 95% CI Upper'],
            decimal_places=0
        )
        
        # CPU
        cpu_med, cpu_ci = format_value_with_ci(
            row['CPU (%) - Median'],
            row['CPU (%) - 95% CI Lower'],
            row['CPU (%) - 95% CI Upper'],
            decimal_places=1
        )
        
        # First row: language, engine, and medians
        latex.append(f"{lang:8} & {engine:6} & {wt_med} & {mem_med} & {cpu_med} \\\\")
        # Second row: CIs
        latex.append(f"         &        & {wt_ci} & {mem_ci} & {cpu_ci} \\\\")
        
        if idx < len(stats_df) - 1:
            latex.append(r"\addlinespace")
    
    latex.append(r"\bottomrule")
    latex.append(r"\multicolumn{5}{l}{\footnotesize $n = " + str(int(stats_df['n_trials'].iloc[0])) + 
                 r"$ trials per configuration; CI calculated using bootstrap resampling} \\")
    latex.append(r"\end{tabular}")
    latex.append(r"\end{table}")
    
    return "\n".join(latex)


def generate_compact_table(stats_df: pd.DataFrame) -> str:
    """
    Generate compact LaTeX table with ± notation.
    """
    latex = []
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(r"\caption{Performance Summary (Median ± 95\% CI Half-Width)}")
    latex.append(r"\label{tab:performance_compact}")
    latex.append(r"\begin{tabular}{llccc}")
    latex.append(r"\toprule")
    latex.append(r"Language & Engine & Walltime (ms) & Memory (KB) & CPU (\%) \\")
    latex.append(r"\midrule")
    
    for idx, row in stats_df.iterrows():
        lang = row.get('language', 'N/A').capitalize()
        engine = row.get('engine', 'N/A')
        
        # Calculate half-widths
        wt_hw = (row['Walltime (ms) - 95% CI Upper'] - row['Walltime (ms) - 95% CI Lower']) / 2
        mem_hw = (row['Memory (KB) - 95% CI Upper'] - row['Memory (KB) - 95% CI Lower']) / 2
        cpu_hw = (row['CPU (%) - 95% CI Upper'] - row['CPU (%) - 95% CI Lower']) / 2
        
        wt_str = f"{row['Walltime (ms) - Median']:,.0f} ± {wt_hw:,.0f}"
        mem_str = f"{row['Memory (KB) - Median']:,.0f} ± {mem_hw:,.0f}"
        cpu_str = f"{row['CPU (%) - Median']:.1f} ± {cpu_hw:.1f}"
        
        latex.append(f"{lang:8} & {engine:6} & {wt_str} & {mem_str} & {cpu_str} \\\\")
    
    latex.append(r"\bottomrule")
    latex.append(r"\multicolumn{5}{l}{\footnotesize $n = " + str(int(stats_df['n_trials'].iloc[0])) + 
                 r"$ trials; CI calculated using bootstrap resampling} \\")
    latex.append(r"\end{tabular}")
    latex.append(r"\end{table}")
    
    return "\n".join(latex)


def generate_simple_csv_table(stats_df: pd.DataFrame) -> str:
    """
    Generate simple CSV format table.
    """
    output = []
    output.append("Language,Engine,Walltime (ms),Memory (KB),CPU (%)")
    
    for idx, row in stats_df.iterrows():
        lang = row.get('language', 'N/A').capitalize()
        engine = row.get('engine', 'N/A')
        
        wt = f"{row['Walltime (ms) - Median']:.0f} [{row['Walltime (ms) - 95% CI Lower']:.0f}-{row['Walltime (ms) - 95% CI Upper']:.0f}]"
        mem = f"{row['Memory (KB) - Median']:.0f} [{row['Memory (KB) - 95% CI Lower']:.0f}-{row['Memory (KB) - 95% CI Upper']:.0f}]"
        cpu = f"{row['CPU (%) - Median']:.1f} [{row['CPU (%) - 95% CI Lower']:.1f}-{row['CPU (%) - 95% CI Upper']:.1f}]"
        
        output.append(f"{lang},{engine},{wt},{mem},{cpu}")
    
    return "\n".join(output)


def generate_markdown_table(stats_df: pd.DataFrame) -> str:
    """
    Generate Markdown table.
    """
    output = []
    output.append("| Language | Engine | Walltime (ms) | Memory (KB) | CPU (%) |")
    output.append("|----------|--------|---------------|-------------|---------|")
    
    for idx, row in stats_df.iterrows():
        lang = row.get('language', 'N/A').capitalize()
        engine = row.get('engine', 'N/A')
        
        wt = f"{row['Walltime (ms) - Median']:,.0f}<br>[{row['Walltime (ms) - 95% CI Lower']:,.0f}–{row['Walltime (ms) - 95% CI Upper']:,.0f}]"
        mem = f"{row['Memory (KB) - Median']:,.0f}<br>[{row['Memory (KB) - 95% CI Lower']:,.0f}–{row['Memory (KB) - 95% CI Upper']:,.0f}]"
        cpu = f"{row['CPU (%) - Median']:.1f}<br>[{row['CPU (%) - 95% CI Lower']:.1f}–{row['CPU (%) - 95% CI Upper']:.1f}]"
        
        output.append(f"| {lang} | {engine} | {wt} | {mem} | {cpu} |")
    
    return "\n".join(output)


def main():
    parser = argparse.ArgumentParser(
        description='Generate LaTeX tables from benchmark statistics CSV'
    )
    parser.add_argument(
        'stats_file',
        help='Path to the statistics CSV file (output from calculate_stats.py)'
    )
    parser.add_argument(
        '-f', '--format',
        choices=['full', 'compact', 'both', 'csv', 'markdown'],
        default='both',
        help='Table format to generate (default: both)'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output file (if not specified, prints to stdout)'
    )
    
    args = parser.parse_args()
    
    # Load statistics
    stats_df = pd.read_csv(args.stats_file)
    
    output_lines = []
    
    if args.format == 'full' or args.format == 'both':
        output_lines.append("% Full table with median and CI on separate lines")
        output_lines.append(generate_full_table(stats_df))
        output_lines.append("")
    
    if args.format == 'compact' or args.format == 'both':
        if args.format == 'both':
            output_lines.append("% Compact table with ± notation")
        output_lines.append(generate_compact_table(stats_df))
        output_lines.append("")
    
    if args.format == 'csv':
        output_lines.append(generate_simple_csv_table(stats_df))
    
    if args.format == 'markdown':
        output_lines.append(generate_markdown_table(stats_df))
    
    output_text = "\n".join(output_lines)
    
    if args.output:
        output_path = Path(args.output)
        output_path.write_text(output_text)
        print(f"Table written to: {output_path}")
    else:
        print(output_text)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Enhanced benchmarking script with accurate memory and CPU metrics using psutil.
This provides more reliable cross-platform resource monitoring.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from typing import Dict, Optional

try:
    import psutil
except ImportError:
    print("Error: psutil is required for resource monitoring.", file=sys.stderr)
    print("Install it with: pip install psutil", file=sys.stderr)
    sys.exit(1)


def monitor_process(pid: int, interval: float = 0.1) -> Dict[str, float]:
    """Monitor a process and return resource usage metrics."""
    try:
        process = psutil.Process(pid)
        max_memory = 0
        cpu_samples = []
        
        while process.is_running():
            try:
                # Memory in KB
                mem_info = process.memory_info()
                current_memory = mem_info.rss / 1024  # Convert bytes to KB
                max_memory = max(max_memory, current_memory)
                
                # CPU percentage
                cpu_percent = process.cpu_percent(interval=interval)
                if cpu_percent > 0:  # Only count non-zero samples
                    cpu_samples.append(cpu_percent)
                
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                break
        
        avg_cpu = sum(cpu_samples) / len(cpu_samples) if cpu_samples else 0
        
        return {
            "max_memory_kb": max_memory,
            "avg_cpu_percent": avg_cpu
        }
    except psutil.NoSuchProcess:
        return {
            "max_memory_kb": 0,
            "avg_cpu_percent": 0
        }


def run_elixir(agents: int, iterations: int, seed: int, chunk_size: int, engine: str, 
               topology: str, script_dir: str, verbose: bool = False) -> Dict[str, float]:
    """Run Elixir simulation and measure resources."""
    elixir_dir = os.path.join(script_dir, "elixir")
    
    # Convert topology to Elixir format
    if topology == "all":
        topo_arg = ":all"
    else:
        topo_arg = topology
    
    if engine == "base":
        expr = f"IO.inspect(MiniSim.run({agents}, {iterations}, {seed}, {chunk_size}, {topo_arg}))"
    elif engine == "proc":
        expr = f"IO.inspect(MiniSim.Proc.run({agents}, {iterations}, {seed}, {chunk_size}))"
    else:
        raise ValueError(f"Unknown engine: {engine}")
    
    cmd = ["mix", "run", "-e", expr]
    env = os.environ.copy()
    env["MIX_ENV"] = "prod"
    
    start_time = time.time()
    
    process = subprocess.Popen(
        cmd,
        cwd=elixir_dir,
        env=env,
        stdout=subprocess.PIPE if not verbose else None,
        stderr=subprocess.PIPE if not verbose else None
    )
    
    # Monitor the process
    metrics = monitor_process(process.pid)
    
    # Wait for completion
    process.wait()
    
    end_time = time.time()
    walltime_ms = int((end_time - start_time) * 1000)
    
    return {
        "walltime_ms": walltime_ms,
        **metrics
    }


def run_python(agents: int, iterations: int, seed: int, chunk_size: int, procs: int,
               topology: str, script_dir: str, verbose: bool = False) -> Dict[str, float]:
    """Run Python simulation and measure resources."""
    py_main = os.path.join(script_dir, "python", "main.py")
    
    cmd = [
        "python3", py_main,
        "--agents", str(agents),
        "--iterations", str(iterations),
        "--seed", str(seed),
        "--chunk-size", str(chunk_size),
        "--procs", str(procs),
        "--topology", topology
    ]
    
    start_time = time.time()
    
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE if not verbose else None,
        stderr=subprocess.PIPE if not verbose else None
    )
    
    # Monitor the process
    metrics = monitor_process(process.pid)
    
    # Wait for completion
    process.wait()
    
    end_time = time.time()
    walltime_ms = int((end_time - start_time) * 1000)
    
    return {
        "walltime_ms": walltime_ms,
        **metrics
    }


def main():
    parser = argparse.ArgumentParser(
        description="Enhanced benchmarking with memory and CPU metrics"
    )
    parser.add_argument("language", choices=["elixir", "python"],
                       help="Language to benchmark")
    parser.add_argument("-a", "--agents", type=int, required=True,
                       help="Community size")
    parser.add_argument("-i", "--iterations", type=int, required=True,
                       help="Number of iterations")
    parser.add_argument("-s", "--seed", type=int, default=42,
                       help="RNG seed (default: 42)")
    parser.add_argument("-c", "--chunk-size", type=int, default=256,
                       help="Batch size (default: 256)")
    parser.add_argument("-E", "--engine", choices=["base", "proc"], default="base",
                       help="Elixir engine: base or proc (default: base)")
    parser.add_argument("-p", "--procs", type=int, default=1,
                       help="Python worker processes (default: 1)")
    parser.add_argument("-t", "--topology", type=str, default="all",
                       help="Topology: 'all' for all-pairs or integer k for random matching (default: all)")
    parser.add_argument("-o", "--output", choices=["csv", "json"], default="csv",
                       help="Output format: csv or json (default: csv)")
    parser.add_argument("-v", "--verbose", action="store_true",
                       help="Print program output")
    
    args = parser.parse_args()
    
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    try:
        if args.language == "elixir":
            results = run_elixir(
                args.agents, args.iterations, args.seed, args.chunk_size,
                args.engine, args.topology, script_dir, args.verbose
            )
        else:
            results = run_python(
                args.agents, args.iterations, args.seed, args.chunk_size,
                args.procs, args.topology, script_dir, args.verbose
            )
        
        if args.output == "json":
            print(json.dumps(results))
        else:
            print(f"{results['walltime_ms']},{results['max_memory_kb']:.0f},{results['avg_cpu_percent']:.2f}")
        
        return 0
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

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
    """Monitor a process and return resource usage metrics.
    
    Uses overall system CPU for accurate multi-core measurement,
    and per-process memory tracking for accurate memory usage,
    assuming the benchmark runs on an isolated machine.
    """
    try:
        process = psutil.Process(pid)
        max_memory = 0
        cpu_samples = []
        
        # Initialize system CPU measurement
        psutil.cpu_percent(interval=None, percpu=False)
        
        while True:
            try:
                # Check if process is still running
                if not process.is_running() or process.status() == psutil.STATUS_ZOMBIE:
                    break
                
                # Get all processes in this tree (parent + all descendants)
                all_procs = [process]
                try:
                    all_procs.extend(process.children(recursive=True))
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
                
                # Memory in KB (sum across all processes in the tree)
                current_memory = 0
                try:
                    for proc in all_procs:
                        try:
                            mem_info = proc.memory_info()
                            current_memory += mem_info.rss / 1024
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            pass
                    
                    max_memory = max(max_memory, current_memory)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
                
                # Measure overall system CPU usage
                # This returns percentage where 100% = all cores fully utilized
                # We need to convert to per-core basis (so 800% on 8 cores = 100% here)
                cpu_percent_total = psutil.cpu_percent(interval=None, percpu=False)
                
                # Convert to per-core percentage (multiply by number of cores)
                # This makes it consistent with per-process measurement conventions
                num_cores = psutil.cpu_count() or 1
                cpu_percent = (cpu_percent_total / 100.0) * num_cores * 100.0
                
                # Only record non-zero samples
                if cpu_percent > 0:
                    cpu_samples.append(cpu_percent)
                
                # Sleep before next sample
                time.sleep(interval)
                
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
        expr = f"IO.inspect(MiniSim.Proc.run({agents}, {iterations}, {seed}, {chunk_size}, {topo_arg}))"
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
    
    # Monitor the process in a separate thread to avoid blocking
    import threading
    monitor_metrics = {}
    
    def monitor():
        result = monitor_process(process.pid)
        monitor_metrics.update(result)
    
    monitor_thread = threading.Thread(target=monitor, daemon=True)
    monitor_thread.start()
    
    # Wait for completion with timeout (10 minutes max)
    try:
        process.wait(timeout=600)
    except subprocess.TimeoutExpired:
        process.kill()
        raise TimeoutError("Elixir process timed out after 10 minutes")
    
    # Give monitor thread a moment to finish
    monitor_thread.join(timeout=1.0)
    
    end_time = time.time()
    walltime_ms = int((end_time - start_time) * 1000)
    
    # Use monitored metrics or defaults
    max_memory_kb = monitor_metrics.get("max_memory_kb", 0)
    avg_cpu_percent = monitor_metrics.get("avg_cpu_percent", 0)
    
    return {
        "walltime_ms": walltime_ms,
        "max_memory_kb": max_memory_kb,
        "avg_cpu_percent": avg_cpu_percent
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
    
    # Monitor the process in a separate thread to avoid blocking
    import threading
    monitor_metrics = {}
    
    def monitor():
        result = monitor_process(process.pid)
        monitor_metrics.update(result)
    
    monitor_thread = threading.Thread(target=monitor, daemon=True)
    monitor_thread.start()
    
    # Wait for completion with timeout (10 minutes max)
    try:
        process.wait(timeout=600)
    except subprocess.TimeoutExpired:
        process.kill()
        raise TimeoutError("Python process timed out after 10 minutes")
    
    # Give monitor thread a moment to finish
    monitor_thread.join(timeout=1.0)
    
    end_time = time.time()
    walltime_ms = int((end_time - start_time) * 1000)
    
    # Use monitored metrics or defaults
    max_memory_kb = monitor_metrics.get("max_memory_kb", 0)
    avg_cpu_percent = monitor_metrics.get("avg_cpu_percent", 0)
    
    return {
        "walltime_ms": walltime_ms,
        "max_memory_kb": max_memory_kb,
        "avg_cpu_percent": avg_cpu_percent
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

# Fix for Hanging Benchmark on AWS Ubuntu

## Problem

The `benchmark_both_topologies.sh` script was hanging on AWS Ubuntu when running benchmarks, specifically during the first Elixir trial. The hang occurred at:

```
Benchmarking Elixir (base engine)...
  Trial 1/5
```

## Root Cause

The issue was in `benchmark_monitor.py` in the `monitor_process()` function:

1. **Blocking CPU measurement**: The original code used `process.cpu_percent(interval=0.1)` which blocks for 100ms on each iteration, making the monitoring loop sluggish
2. **Poor process exit detection**: The loop only checked `process.is_running()` without checking for zombie processes
3. **Sequential monitoring**: The monitoring happened synchronously, blocking the main thread until the process exited, but the monitor loop itself might not detect the exit properly
4. **No timeout protection**: There was no timeout mechanism to prevent infinite hangs

## Changes Made

### 1. Fixed `monitor_process()` function:

- **Added explicit zombie process check**: Now checks `process.status() == psutil.STATUS_ZOMBIE`
- **Non-blocking CPU measurement**: Changed `cpu_percent(interval=0.1)` to `cpu_percent(interval=0)` (non-blocking)
- **Added explicit sleep**: Added `time.sleep(interval)` to avoid busy-waiting while still sampling regularly
- **Better child process tracking**: Now includes memory from child processes for more accurate measurements
- **Initialize CPU counter**: Added initial `process.cpu_percent()` call to properly initialize the counter

### 2. Refactored `run_elixir()` and `run_python()`:

- **Threading**: Moved monitoring to a separate daemon thread so it doesn't block the main process
- **Timeout protection**: Added 10-minute timeout to `process.wait()` to prevent infinite hangs
- **Graceful shutdown**: Gives the monitor thread 1 second to finish after process completes
- **Error handling**: Kills the process and raises TimeoutError if it exceeds the timeout

## Key Improvements

1. **Non-blocking monitoring**: The monitor thread runs independently and won't block process completion
2. **Proper exit detection**: Multiple checks ensure the process exit is detected (zombie status, is_running, NoSuchProcess exception)
3. **Timeout safety**: 10-minute timeout prevents infinite hangs
4. **Better resource tracking**: Includes child process memory for more accurate measurements

## Testing

To test the fix on AWS Ubuntu:

```bash
# Test with a simple run first
python3 benchmark_monitor.py elixir -a 10 -i 10 -E base -t all

# Then run the full benchmark
./benchmark_both_topologies.sh -a 300 -i 10 -t 5
```

## Technical Details

The original issue occurred because:
- On some systems (especially virtualized environments like AWS), `psutil.Process.is_running()` can return True even after the process has finished if it's in a zombie state
- Blocking CPU measurement with `interval=0.1` meant the loop took at least 100ms per iteration, making it slow to detect process exit
- The sequential nature meant if the monitor loop hung, the entire benchmark would hang

The threading approach solves this by:
- Letting the main thread wait on the actual process (with timeout)
- Having the monitor run independently and exit when it detects the process is done
- Using non-blocking CPU measurement so the monitor can check process status frequently


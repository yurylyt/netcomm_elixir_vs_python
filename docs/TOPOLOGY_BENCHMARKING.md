# Topology Benchmarking Quick Reference

This guide provides quick examples for benchmarking different interaction topologies.

## Quick Commands

### 1. Single Run - Compare Topologies

```bash
# All-pairs topology (exhaustive O(n²))
../scripts/run_sim.sh elixir -a 200 -i 100 -t all
../scripts/run_sim.sh python -a 200 -i 100 -t all -p 8

# Random matching topology (k=8, approximately O(n×k))
../scripts/run_sim.sh elixir -a 200 -i 100 -t 8
../scripts/run_sim.sh python -a 200 -i 100 -t 8 -p 8
```

### 2. Sweep - Multiple Community Sizes

```bash
# Sweep all-pairs
./sweep_sim.sh elixir 100 300 -i 100 -t all
./sweep_sim.sh python 100 300 -i 100 -p 8 -t all

# Sweep random matching (k=8)
./sweep_sim.sh elixir 100 300 -i 100 -t 8
./sweep_sim.sh python 100 300 -i 100 -p 8 -t 8
```

### 3. Multi-Trial Benchmarks

```bash
# Benchmark all-pairs with 5 trials
../scripts/benchmark_trials_enhanced.sh -a 300 -i 100 -t 5 -T all -o results_all_pairs.csv

# Benchmark random-8 with 5 trials
../scripts/benchmark_trials_enhanced.sh -a 300 -i 100 -t 5 -T 8 -o results_random_k8.csv

# Comprehensive comparison (both topologies)
./benchmark_both_topologies.sh -a 300 -i 100 -t 5 -k 8
```

### 4. All Engines - Both Topologies

```bash
# Run the comprehensive sweep script
./sweep_em_all.sh
```

This will run:
- Elixir base engine (all-pairs)
- Elixir proc engine (all-pairs)
- Python multiprocess (all-pairs)
- Elixir base engine (random k=8)
- Python multiprocess (random k=8)

## Understanding the Results

### Complexity Comparison

| Topology | Pairs/Iteration | Example (n=300) | Time Complexity |
|----------|----------------|-----------------|-----------------|
| All-pairs | n(n-1)/2 | 44,850 | O(n²) |
| Random k=3 | ~n×k/2 | ~450 | O(n×k) |
| Random k=8 | ~n×k/2 | ~1,200 | O(n×k) |
| Random k=20 | ~n×k/2 | ~3,000 | O(n×k) |

### Performance Expectations

**All-pairs:**
- Maximum interaction density
- Best for complete mixing models
- Scales quadratically - slow for large n
- Example: n=300 → ~45k pairs, n=600 → ~180k pairs (4× slower)

**Random matching (k=8):**
- Sparse interaction pattern
- Better scalability for large communities
- Linear scaling with n (for fixed k)
- Example: n=300 → ~1.2k pairs, n=600 → ~2.4k pairs (2× slower)

### Speed Improvement Estimate

For n=300, iterations=100:

| Implementation | All-pairs | Random k=8 | Speedup |
|----------------|-----------|------------|---------|
| Elixir base | ~15s | ~1s | ~15× |
| Python multi | ~8s | ~0.5s | ~16× |

Note: Actual speedup depends on k value and system configuration.

## Choosing k for Random Matching

Guidelines for selecting the k parameter:

- **k=3-5**: Very sparse network, minimal interaction
  - Use case: Testing extreme scalability (n > 10,000)
  
- **k=8-10**: Moderate sparse network
  - Use case: Realistic social networks, large communities (n=1,000-10,000)
  
- **k=20-50**: Dense network
  - Use case: Tightly connected communities (n=500-2,000)
  
- **k > n/2**: Approaching all-pairs
  - Use case: Small communities with high connectivity

## Example Workflow

```bash
# 1. Quick test with small community
../scripts/run_sim.sh elixir -a 50 -i 10 -t 8

# 2. Sweep to find scaling behavior
./sweep_sim.sh elixir 100 500 -i 50 -t 8

# 3. Full benchmark with statistics
../scripts/benchmark_trials_enhanced.sh -a 300 -i 100 -t 10 -T 8

# 4. Compare both topologies
./benchmark_both_topologies.sh -a 300 -i 100 -t 5 -k 8

# 5. Analyze results
python3 -c 'import pandas as pd; print(pd.read_csv("benchmark_results_all_pairs.csv").groupby(["language","engine"]).agg({"walltime_ms":"mean"}))'
python3 -c 'import pandas as pd; print(pd.read_csv("benchmark_results_random_k8.csv").groupby(["language","engine"]).agg({"walltime_ms":"mean"}))'
```

## Troubleshooting

**Issue:** "Random matching requires k in range 1..N-1"
- **Solution:** Make sure k < number of agents. For 100 agents, max k is 99.

**Issue:** Proc engine ignoring topology parameter
- **Solution:** Proc engine only supports all-pairs. Use base engine for random matching.

**Issue:** Results not deterministic
- **Solution:** Ensure you're using the same seed (-s option) and topology parameter.

## Advanced: Custom Topology Benchmarks

To benchmark a range of k values:

```bash
for k in 3 5 8 10 15 20; do
  echo "Benchmarking k=$k"
  ../scripts/benchmark_trials_enhanced.sh -a 300 -i 100 -t 3 -T $k -o "results_k${k}.csv"
done

# Combine results
echo "K,Language,Engine,Mean_Walltime_ms"
for k in 3 5 8 10 15 20; do
  python3 -c "import pandas as pd; df=pd.read_csv('results_k${k}.csv'); print(df.groupby(['language','engine'])['walltime_ms'].mean().to_csv(header=False).replace('\n',' | k=$k\n'))"
done
```

This will help identify the optimal k value for your specific use case.

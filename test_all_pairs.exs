# Test script to compare base and proc engines with all-pairs topology
seed = 42
agents = 10
iterations = 2
topology = :all

IO.puts("Testing with seed=#{seed}, agents=#{agents}, iterations=#{iterations}, topology=#{topology}\n")

IO.puts("Base engine:")
base_result = MiniSim.run(agents, iterations, seed, 256, topology)
IO.inspect(base_result)

IO.puts("\nProc engine:")
proc_result = MiniSim.Proc.run(agents, iterations, seed, 256, topology)
IO.inspect(proc_result)

IO.puts("\nAre they equal? #{base_result == proc_result}")

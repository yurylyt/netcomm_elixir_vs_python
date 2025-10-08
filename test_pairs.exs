# Test if pair generation is the same
seed = 42
n = 10
k = 8
tick = 1

# From Simulation module
iteration_seed = :erlang.phash2({seed, tick, :random_pairs})
IO.puts("Iteration seed for tick #{tick}: #{iteration_seed}")

# Manually generate pairs using the same logic
rng = MiniSim.Rng.new(iteration_seed)

{pairs, _} = Enum.reduce(0..(n - 1), {[], rng}, fn i, {acc_pairs, r} ->
  {agent_pairs, r2} = Enum.reduce(1..k, {[], r}, fn _, {pairs, r_inner} ->
    {u, rng2} = MiniSim.Rng.uniform(r_inner)
    j_raw = trunc(u * (n - 1))
    j = if j_raw >= i, do: j_raw + 1, else: j_raw
    {[{i, j} | pairs], rng2}
  end)
  {agent_pairs ++ acc_pairs, r2}
end)

pairs = pairs
  |> Enum.map(fn {i, j} -> if i < j, do: {i, j}, else: {j, i} end)
  |> Enum.uniq()
  |> Enum.sort()

IO.puts("\nGenerated #{length(pairs)} unique pairs:")
IO.inspect(pairs)

# Build partner map
partner_map = Enum.reduce(pairs, %{}, fn {i, j}, acc ->
  acc
  |> Map.update(i, [j], &[j | &1])
  |> Map.update(j, [i], &[i | &1])
end)

IO.puts("\nPartner map:")
Enum.each(0..(n-1), fn i ->
  partners = Map.get(partner_map, i, [])
  IO.puts("Agent #{i}: #{length(partners)} partners -> #{inspect(Enum.sort(partners))}")
end)

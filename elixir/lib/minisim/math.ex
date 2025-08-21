defmodule MiniSim.Math do
  def random_choice(preference_density) do
    random = :rand.uniform()

    preference_density
    |> Enum.with_index()
    |> Enum.reduce_while(0, fn {prob, index}, acc ->
      if random <= acc + prob do
        {:halt, index}
      else
        {:cont, acc + prob}
      end
    end)
  end

  def normalized_entropy(probs) do
    entropy = probs
    |> Enum.map(fn
      p when p <= 0.0 -> 0.0
      p -> -p * :math.log2(p)
    end)
    |> Enum.sum()

    max_entropy = :math.log2(length(probs))
    entropy / max_entropy
  end

  def bernoulli_trial(p) do
    :rand.uniform() <= p
  end
end


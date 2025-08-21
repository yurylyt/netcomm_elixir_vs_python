defmodule MiniSim.Model.Agent do
  @moduledoc """
  Represents an agent with:
  - rho: resistance to change (0..1)
  - pi: persuasiveness (0..1)
  - preferences: probability distribution over 3 alternatives
  """

  defstruct [
    :rho,
    :pi,
    :preferences
  ]

  @type t :: %__MODULE__{
          rho: float(),
          pi: float(),
          preferences: [float()]
        }

  @doc """
  Creates a new agent. `option1_pref` is the probability of alternative 1; alt2=1-option1_pref; alt3=0.
  """
  def new_agent(rho, pi, option1_pref) do
    %__MODULE__{
      rho: rho,
      pi: pi,
      preferences: [option1_pref, 1 - option1_pref, 0.0]
    }
  end

  @doc """
  Returns an alternative index (0, 1, or 2) sampled from current preferences.
  """
  @spec vote(t) :: 0 | 1 | 2
  def vote(agent) do
    random = :rand.uniform()

    agent.preferences
    |> Enum.with_index()
    |> Enum.reduce_while(0, fn {prob, index}, acc ->
      if random <= acc + prob do
        {:halt, index}
      else
        {:cont, acc + prob}
      end
    end)

  end
end

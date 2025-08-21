defmodule MiniSim.Model.Agent do
  @moduledoc """
  Represents an agent with:
  - rho: resistance to change (0..1)
  - pi: persuasiveness (0..1)
  - preferences: probability distribution over 3 alternatives
  - decisiveness: sensitivity to uncertainty
  """

  import MiniSim.Math

  defstruct [
    :rho,
    :pi,
    :preferences,
    :decisiveness
  ]

  @type t :: %__MODULE__{
          rho: float(),
          pi: float(),
          preferences: [float()],
          decisiveness: float()
        }

  @doc """
  Creates a new agent. `option1_pref` is the probability of alternative 1; alt2=1-option1_pref; alt3=0.
  """
  def new_agent(rho, pi, option1_pref, decisiveness \\ 0.0) do
    %__MODULE__{
      rho: rho,
      pi: pi,
      preferences: [option1_pref, 1 - option1_pref, 0.0],
      decisiveness: decisiveness
    }
  end

  @doc """
  Returns either an alternative index (0,1,2) or :disclaim if declining to choose.
  """
  @spec vote(t) :: integer | :disclaim
  def vote(agent) do
    entropy = normalized_entropy(agent.preferences)
    pow = :math.exp(agent.decisiveness)
    trial = bernoulli_trial(:math.pow(entropy, pow))

    case trial do
      true -> :disclaim
      false -> random_choice(agent.preferences)
    end
  end
end


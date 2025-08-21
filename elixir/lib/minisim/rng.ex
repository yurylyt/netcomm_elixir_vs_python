defmodule MiniSim.Rng do
  @moduledoc """
  Simple 64-bit LCG RNG shared across languages for reproducibility.
  state_{n+1} = (a * state_n + c) mod 2^64
  uniform in [0,1) = state / 2^64
  """

  @mod 18_446_744_073_709_551_616
  @a 636_413_622_384_679_300_5
  @c 1_442_695_040_888_963_407

  @type state :: non_neg_integer()

  @spec new(integer()) :: state
  def new(seed) when is_integer(seed) do
    s = rem(seed, @mod)
    if s < 0, do: s + @mod, else: s
  end

  @spec next(state) :: state
  def next(state) do
    rem(@a * state + @c, @mod)
  end

  @spec uniform(state) :: {float(), state}
  def uniform(state) do
    next_state = next(state)
    {next_state / @mod, next_state}
  end
end

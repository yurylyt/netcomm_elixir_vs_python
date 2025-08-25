defmodule MiniSim.ProcRunTest do
  use ExUnit.Case, async: false

  alias MiniSim.Proc

  test "proc runner returns statistics with correct shape" do
    stats = Proc.run(10, 1, 12345, 256)
    assert %MiniSim.Model.Simulation.Statistics{} = stats
    assert stats.total_agents == 10
    assert length(stats.average_preferences) == 3
    assert length(stats.agent_preferences) == 10
  end

  test "proc and base runners match for small deterministic run" do
    # identical seed and parameters should produce the same result
    base = MiniSim.run(12, 2, 4242, 64)
    proc = Proc.run(12, 2, 4242, 64)
    assert base.total_agents == proc.total_agents
    assert base.vote_results == proc.vote_results
    assert base.average_preferences == proc.average_preferences
    assert base.agent_preferences == proc.agent_preferences
  end
end


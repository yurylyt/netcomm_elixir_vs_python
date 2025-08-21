defmodule MiniSim.MixProject do
  use Mix.Project

  def project do
    [
      app: :mini_sim,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.6.0"}
    ]
  end
end

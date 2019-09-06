defmodule RicochetRobots.MixProject do
  use Mix.Project

  def project do
    [
      app: :ricochet_robots,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {RicochetRobots, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
        {:cowboy, "~> 2.4"},
        {:plug, "~> 1.7"},
        {:plug_cowboy, "~>2.0"},
    ]
  end
end

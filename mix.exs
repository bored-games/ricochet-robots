defmodule RicochetRobots.MixProject do
  use Mix.Project

  def project do
    [
      app: :ricochet_robots,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "RicochetRobots",
      source_url: "https://github.com/gg314/TODO",
      homepage_url: "http://TODO.com",
      docs: [
        # The main page in the docs
        main: "RicochetRobots",
        # 			logo: "path/to/logo.png",
        extras: ["README.md"]
      ]
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
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:cowboy, "~> 2.4"},
      {:plug, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 3.1"}
    ]
  end
end

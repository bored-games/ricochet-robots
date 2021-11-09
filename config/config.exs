import Config

config :gameboy, Gameboy.RicochetRobots.Repo,
  database: "ricochetrobots_repo",
  username: "postgres",
  password: "redf",
  hostname: "localhost"

config :gameboy, ecto_repos: [Gameboy.RicochetRobots.Repo]

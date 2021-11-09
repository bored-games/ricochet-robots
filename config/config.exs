import Config

config :gameboy, Gameboy.RicochetRobots.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: {:system, "DATABASE_URL"},
  database: "",
  ssl: true,
  pool_size: 2

config :gameboy, ecto_repos: [Gameboy.RicochetRobots.Repo]

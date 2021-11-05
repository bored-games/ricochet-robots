import Config

config :gameboy, Gameboy.RicochetRobots.Repo,
  database: "ricochetrobots_repo",
  username: "postgres",
  password: "notarealpassword",
  hostname: "localhost",
  adapter: Ecto.Adapters.Postgres,
  url: "${DATABASE_URL}",
  database: "",
  ssl: true,
  pool_size: 2 # Free tier db only allows 4 connections. Rolling deploys need pool_size*(n+1) connections where n is the number of app replicas.

config :gameboy, ecto_repos: [Gameboy.RicochetRobots.Repo]

config :gameboy, Gameboy,
  http: [port: {:system, "PORT"}], # Possibly not needed, but doesn't hurt
  url: [host: System.get_env("APP_NAME") <> ".gigalixirapp.com", port: 443],
  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE"),
  server: true
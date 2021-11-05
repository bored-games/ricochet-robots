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

config :gen_tcp_accept_and_close, port: 4000
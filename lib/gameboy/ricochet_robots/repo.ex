defmodule Gameboy.RicochetRobots.Repo do
  use Ecto.Repo,
    otp_app: :gameboy,
    adapter: Ecto.Adapters.Postgres
end

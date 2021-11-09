defmodule Gameboy.Router do
  @moduledoc false

  use Plug.Router
  use Logger

  plug(Plug.Static, at: "/", from: {:ricochet_robots, "priv/"})
  plug(:match)
  plug(:dispatch)

  match _ do
    Logger.debug("AAAAAAAAAAAAAA #{inspect({:system, "DATABASE_URL"})}............")
    send_resp(conn, 200, "Success")
  end
end

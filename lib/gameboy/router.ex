require Logger

defmodule Gameboy.Router do
  @moduledoc false

  use Plug.Router

  plug(Plug.Static, at: "/", from: {:ricochet_robots, "priv/"})
  plug(:match)
  plug(:dispatch)

  match _ do
    send_resp(conn, 404, "Not found")
  end
end

defmodule RicochetRobots.Router do
  use Plug.Router

  plug Plug.Static, at: "/", from: {:ricochet_robots, "priv/"}
  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, application_html())
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end

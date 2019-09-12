defmodule RicochetRobots do
  @moduledoc """
  Documentation for RicochetRobots.
  """

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: RicochetRobots.Router,
        options: [
          dispatch: dispatch(),
          port: 4000
        ]
      ),
      Registry.child_spec(
        keys: :duplicate,
        name: Registry.RicochetRobots
      ),
      RicochetRobots.RoomSupervisor.child_spec(
        name: RicochetRobots.RoomSupervisor
      )
    ]

    opts = [strategy: :one_for_one, name: RicochetRobots.Application]
    Supervisor.start_link(children, opts)
  end

  def dispatch do
    [
      {
        :_,
        [
          {"/ws/[...]", RicochetRobots.SocketHandler, []},
          {:_, Plug.Cowboy.Handler, {RicochetRobots.Router, []}}
        ]
      }
    ]
  end
end

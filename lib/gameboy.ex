defmodule Gameboy do
  @moduledoc """
  A multiplayer server for the popular board game *Ricochet Robots*.
  """

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Gameboy.Router,
        options: [
          dispatch: dispatch(),
          port: 4000
        ]
      ),
      Registry.child_spec(
        keys: :unique,
        name: Registry.RoomRegistry
      ),
      Registry.child_spec(
        keys: :unique,
        name: Registry.GameRegistry
      ),
      Registry.child_spec(
        keys: :unique,
        name: Registry.PlayerRegistry
      ),
      Registry.child_spec(
        keys: :unique,
        name: Registry.RoomPlayerRegistry
      )
    ]

    opts = [strategy: :one_for_one, name: Gameboy.Application]
    Supervisor.start_link(children, opts)
  end

  def dispatch do
    [
      {
        :_,
        [
          {"/ws/[...]", Gameboy.SocketHandler, []},
          {:_, Plug.Cowboy.Handler, {Gameboy.Router, []}}
        ]
      }
    ]
  end
end

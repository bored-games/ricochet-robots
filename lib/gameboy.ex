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
          port: 56765
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
        keys: :duplicate,
        name: Registry.RoomPlayerRegistry
      ),
      Supervisor.child_spec({Gameboy.RoomSupervisor, []}, id: Gameboy.RoomSupervisor),
      Supervisor.child_spec({Gameboy.PlayerSupervisor, []}, id: Gameboy.PlayerSupervisor),
      Supervisor.child_spec({Gameboy.GameSupervisor, []}, id: Gameboy.GameSupervisor),
      %{id: :room1, start: {Gameboy.RoomSupervisor, :start_child, [%{room_name: "Robot City", game_name: "Ricochet Robots"}, :permanent]}, restart: :permanent},
      # %{id: :room2, start: {Gameboy.RoomSupervisor, :start_child, [%{room_name: "Canoe for Two", game_name: "Canoe", player_limit: 2}, :permanent]}, restart: :permanent},
      # %{id: :room3, start: {Gameboy.RoomSupervisor, :start_child, [%{room_name: "I Spy", game_name: "Codenames", player_limit: 10}, :permanent]}, restart: :permanent},
      # %{id: :room4, start: {Gameboy.RoomSupervisor, :start_child, [%{room_name: "Homeworldz", game_name: "Homeworlds", player_limit: 2}, :permanent]}, restart: :permanent},
      # %{id: :room5, start: {Gameboy.RoomSupervisor, :start_child, [%{room_name: "Just Chatting", game_name: nil, player_limit: 32}, :permanent]}, restart: :permanent},
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

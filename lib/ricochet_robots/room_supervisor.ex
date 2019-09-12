defmodule RicochetRobots.RoomSupervisor do
  use Supervisor
  require Logger

  def start_link(init_arg) do
    Logger.debug("started roomsupervisor link")
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(name) do
    children = [
      %{ id: RicochetRobots.Room,
         start: {RicochetRobots.Room, :start_link, name}
    #     restart: :temporary # DO NOT revive dead rooms, for now.
        }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

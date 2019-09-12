defmodule RicochetRobots.RoomSupervisor do
  use Supervisor
  require Logger

  def start_link(name) do
    Logger.debug("started roomsupervisor link")
    Supervisor.start_link(__MODULE__, name)
  end

  @impl true
  def init(name) do
    children = [
      %{id: RicochetRobots.Room, start: {RicochetRobots.Room, :start_link, name}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

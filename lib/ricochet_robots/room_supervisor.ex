defmodule RicochetRobots.RoomSupervisor do
  use Supervisor

  def start_link(name) do
    Supervisor.start_link(__MODULE__, name)
  end

  @impl true
  def init(name) do
    children = [
      %{id: Room, start: {Room, :start_link, name}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

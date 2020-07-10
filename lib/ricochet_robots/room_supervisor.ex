defmodule RicochetRobots.RoomSupervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Logger.debug("Starting RoomSupervisor link with opts: #{inspect(opts)}")
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    children = [
      %{
        id: RicochetRobots.Room,
        start: {RicochetRobots.Room, :start_link, opts}
      }
    ]

    Logger.debug("got this far... #{inspect(opts)}")
    #RicochetRobots.Room.child_spec(room_name: "pizzaParty", name: RicochetRobots.RoomSupervisor)
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end

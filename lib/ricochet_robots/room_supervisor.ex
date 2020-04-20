defmodule RicochetRobots.RoomSupervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Logger.debug("Starting RoomSupervisor link for room \"#{opts["room_name"]}\"")
    Supervisor.start_link(__MODULE__, opts["room_name"])
  end

  @impl true
  def init(opts) do
    children = [
      %{
        id: RicochetRobots.Room,
        start: {RicochetRobots.Room, :start_link, opts}
      }
    ]

    Supervisor.init(children, strategy: :temporary)
  end
end

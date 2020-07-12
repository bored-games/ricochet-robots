defmodule RicochetRobots.RoomSupervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Logger.debug("RoomSupervisor start_link with opts: #{inspect(opts)}")
    Supervisor.start_link(__MODULE__, opts)
  end

  # called any time someone does RoomSupervisor.start_link(opts), obviously
  @impl true
  def init(opts) do
    
    Logger.debug("RoomSupervisor init... #{inspect(opts)}")

    children = [
      %{
        id: RicochetRobots.Room,
        start: {RicochetRobots.Room, :start_link, [opts]}
      },
      # Registry.child_spec(
      #   keys: :unique,
      #   name: Registry.RoomPlayerRegistry
      # )
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end

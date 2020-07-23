defmodule Gameboy.RoomSupervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Logger.debug("RoomSupervisor start_link... #{inspect self()} #{inspect(opts)}")
    Supervisor.start_link(__MODULE__, opts)
  end

  # called any time someone does RoomSupervisor.start_link(opts), obviously
  @impl true
  def init(opts) do
    
    Logger.debug("RoomSupervisor init... #{inspect(opts)} from my PID #{inspect self()}")

    children = [
      %{
        id: Gameboy.Room,
        start: {Gameboy.Room, :start_link, [opts]}
      }
    ]

    children = []
    
    Supervisor.init(children, strategy: :one_for_one, restart: :transient)
  end
end

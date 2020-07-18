defmodule Gameboy.RoomSupervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  # called any time someone does RoomSupervisor.start_link(opts), obviously
  @impl true
  def init(opts) do
    
    Logger.debug("RoomSupervisor init... #{inspect(opts)}")

    children = [
      %{
        id: Gameboy.Room,
        start: {Gameboy.Room, :start_link, [opts]}
      }
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end

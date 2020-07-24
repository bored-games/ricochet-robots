defmodule Gameboy.RoomSupervisor do
  @moduledoc false

  use DynamicSupervisor
  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: :room_sup)
  end

  def start_child(opts, strategy) do # opts is, e.g. %{room_name: room_name, game_name: game_name}
    Logger.debug("OPTIONS : #{inspect opts}")
    spec = %{id: Gameboy.Room, restart: strategy, start: {Gameboy.Room, :start_link, [opts]}}
    DynamicSupervisor.start_child(:room_sup, spec)
  end
  
  # called any time someone does RoomSupervisor.start_link(opts), obviously
  @impl true
  def init(opts) do
    Logger.debug("RoomSupervisor init... #{inspect(opts)} from my PID #{inspect self()}")
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end



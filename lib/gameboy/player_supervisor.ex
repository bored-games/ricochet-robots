defmodule Gameboy.PlayerSupervisor do
  @moduledoc false

  use DynamicSupervisor
  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: :player_sup)
  end

  def start_child(opts) do
    spec = %{id: Gameboy.Player, start: {Gameboy.Player, :start_link, [opts]}}
    DynamicSupervisor.start_child(:player_sup, spec)
  end

  #
  @impl true
  def init(opts) do
    Logger.debug("PlayerSupervisor #{inspect(opts)} initialized with PID #{inspect self()}")
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

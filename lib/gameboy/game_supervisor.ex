defmodule Gameboy.GameSupervisor do
  @moduledoc false

  use DynamicSupervisor
  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: :game_sup)
  end

  def start_child(module, opts) do # opts is, e.g. %{room_name: room_name}
    spec = %{id: module, restart: :transient, start: {module, :start_link, [opts]}}
    DynamicSupervisor.start_child(:game_sup, spec)
  end

  @impl true
  def init(opts) do
    Logger.debug("GameSupervisor #{inspect(opts)} initialized with PID #{inspect self()}")
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

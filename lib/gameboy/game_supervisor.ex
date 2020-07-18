defmodule Gameboy.GameSupervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  #def init(reg_key) do
  def init(opts) do

    children = [
      # TODO THIS SHOULD NOT BE HARDCODED someday
      %{
        id: Gameboy.RicochetRobots.Main,
        #start: {Gameboy.RicochetRobots.Main, :start_link, [%{registry_key: reg_key}]}
        start: {Gameboy.RicochetRobots.Main, :start_link, [opts]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule RicochetRobots.GameSupervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Logger.debug("Started RR.GameSupervisor link")
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(reg_key) do
    children = [
      # THIS SHOULD NOT BE HARDCODED someday
      %{
        id: RicochetRobots.Game,
        start: {RicochetRobots.Game, :start_link, [%{registry_key: reg_key}]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

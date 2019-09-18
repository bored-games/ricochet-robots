defmodule RicochetRobots.GameSupervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Logger.debug("started gamesupervisor link")
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(reg_key) do
    children = [
      %{id: RicochetRobots.Game, start: {RicochetRobots.Game, :start_link, [%{registry_key: reg_key}]}} # THIS SHOULD NOT BE HARDCODED
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

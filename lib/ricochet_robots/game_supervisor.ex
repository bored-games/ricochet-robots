defmodule RicochetRobots.GameSupervisor do
  use Supervisor
  require Logger

  def start_link(name) do
    Logger.debug("started gamesupervisor link")
    Supervisor.start_link(__MODULE__, name)
  end

  @impl true
  def init(name) do
    children = [
      %{id: RicochetRobots.Game, start: {RicochetRobots.Game, :start_link, name}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

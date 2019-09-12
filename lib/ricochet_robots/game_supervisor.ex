defmodule RicochetRobots.GameSupervisor do
  use Supervisor
  require Logger

  def start_link(init_arg) do
    Logger.debug("started gamesupervisor link")
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
    {:ok, 231}
  end

  @impl true
  def init(_name) do
    children = [
      %{ id: RicochetRobots.Game,
         start: {RicochetRobots.Game, :start_link, ["arg1"]}
       }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

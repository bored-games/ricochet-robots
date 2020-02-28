defmodule RicochetRobots.PlayerSupervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Logger.debug("Starting PlayerSupervisor link for player \"#{opts[:player_name]}\"")
    Supervisor.start_link(__MODULE__, opts[:player_name])
  end

  @impl true
  def init(opts) do
    children = [
      %{
        id: RicochetRobots.Player,
        start: {RicochetRobots.Player, :start_link, opts}
      }
    ]

    Supervisor.init(children, strategy: :temporary)
  end
end

defmodule RicochetRobots.Room do
  use GenServer
  require Logger

  defstruct name: nil,
            game: nil,
            players: [],
            value: "IDK",
            chat: []

  def start_link(_opts) do
    Logger.debug("started room link")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.debug("[Room: Started Room]")
    new_room =  %__MODULE__{name: "Pizza House"}
    {:ok, new_room}
  end

  def create_game() do
    GenServer.cast(__MODULE__, {:create_game})
    Logger.debug("[Room: Created Game]")
  end

  def add_player(player) do
    GenServer.cast(__MODULE__, {:add_player, player})
  end

  def user_chat(registry_key, player, message) do
    GenServer.cast(__MODULE__, {:user_chat, registry_key, player, message})
  end

  def system_chat(registry_key, message) do
    GenServer.cast(__MODULE__, {:system_chat, registry_key, message})
  end

  @impl true
  def handle_cast({:create_game}, state) do
    game = RicochetRobots.GameSupervisor.start_link(RicochetRobots.GameSupervisor)
    {:noreply, Map.put(state, :game, game)}
  end

  @impl true
  def handle_cast({:add_player, player}, state) do
    state = %{state | players: [player | state.players]}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:user_chat, registry_key, player, message}, state) do
  #  Logger.debug("[User chat] <#{player}> #{message}")

    response = Poison.encode!( %{ content: %{ user: player, msg: message, kind: 0}, action: "update_chat" }  )

    # send chat message to all
    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn(entries) ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

  #  state = %{state | chat: ["<#{player}> #{message}" | state.chat]}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:system_chat, registry_key, message}, state) do
    Logger.debug("[System chat] #{message}")
    system_user = %{username: "System", color: "#c6c6c6", score: 0, is_admin: false, is_muted: false}
    json_test = Poison.encode!(%{content: %{ user: system_user, msg: message, kind: 1 }, action: "update_chat" })

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn(entries) ->
      for {pid, _} <- entries do
        Process.send(pid, json_test, [])
      end
    end)

    # store chat in state?
    state = %{state | chat: [message | state.chat]}
    {:noreply, state}
  end
end

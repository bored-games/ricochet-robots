defmodule RicochetRobots.Room do
  use GenServer
  require Logger

  defstruct name: nil,
            game: nil,
            users: [],
            chat: []

  def start_link(_opts) do
    Logger.debug("started room link")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.debug("[Room: Started Room]")
    new_room = %__MODULE__{name: "Pizza House"}
    {:ok, new_room}
  end

  def create_game() do
    GenServer.cast(__MODULE__, {:create_game})
    Logger.debug("[Room: Created Game]")
  end

  def add_user(user) do
    GenServer.cast(__MODULE__, {:add_user, user})
  end

  def update_user(key) do
    GenServer.cast(__MODULE__, {:update_user, key})
  end

  def remove_user(key) do
    GenServer.cast(__MODULE__, {:remove_user, key})
  end

  def broadcast_scoreboard(registry_key) do
    GenServer.cast(__MODULE__, {:broadcast_scoreboard, registry_key})
  end

  def user_chat(registry_key, user, message) do
    GenServer.cast(__MODULE__, {:user_chat, registry_key, user, message})
  end

  def system_chat(registry_key, message, message2 \\ {0, ""}) do
    GenServer.cast(__MODULE__, {:system_chat, registry_key, message, message2})
  end

  @impl true
  def handle_cast({:create_game}, state) do
    game = RicochetRobots.GameSupervisor.start_link(RicochetRobots.GameSupervisor)
    {:noreply, Map.put(state, :game, game)}
  end

  @impl true
  def handle_cast({:add_user, user}, state) do
    {:noreply, %{state | users: [user | state.users]}}
  end

  @impl true
  def handle_cast({:update_user, updated_user}, state) do
    users = Enum.map(state.users, fn u -> (if u.unique_key == updated_user.unique_key do updated_user else u end) end)
    {:noreply, %{state | users: users}}
  end

  @impl true
  def handle_cast({:remove_user, key}, state) do
    users = Enum.filter(state.users, fn u -> u.unique_key != key end)
    {:noreply, %{state | users: users}}
  end

  @impl true
  def handle_cast({:broadcast_scoreboard, registry_key}, state) do
    Logger.debug("[Get scoreboard]")
    response = Poison.encode!(%{content: state.users, action: "update_scoreboard"})

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:user_chat, registry_key, user, message}, state) do
    Logger.debug("[User chat] <#{user.username}> #{message}")

    response =
      Poison.encode!(%{content: %{user: user, msg: message, kind: 0}, action: "update_chat"})

    # send chat message to all
    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    # TODO: log chat?
    # state = %{state | chat: ["<#{user}> #{message}" | state.chat]}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:system_chat, registry_key, message, {pidmatch, message2}}, state) do
    Logger.debug("[System chat] #{message}")

    system_user = %{
      username: "System",
      color: "#c6c6c6",
      score: 0,
      is_admin: false,
      is_muted: false
    }

    json_msg =
      Poison.encode!(%{
        content: %{user: system_user, msg: message, kind: 1},
        action: "update_chat"
      })

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        if (pid == pidmatch) do
          json_msg2 =
            Poison.encode!(%{
              content: %{user: system_user, msg: message2, kind: 1},
              action: "update_chat"
            })
          Process.send(pid, json_msg2, [])
        else
          Process.send(pid, json_msg, [])
        end
      end
    end)

    # store chat in state?
    state = %{state | chat: [message | state.chat]}
    {:noreply, state}
  end
end

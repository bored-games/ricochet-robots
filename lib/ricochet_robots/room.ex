defmodule RicochetRobots.Room do
  @moduledoc """
  Defines a `Room`.

  A `Room` contains information about current users and can have up to one `game`, e.g. `RicochetRobots.Game`, attached.
  """

  use GenServer
  require Logger

  defstruct name: nil,
            game: nil,
            users: [],
            chat: []

  @doc false
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.debug("[Room: Started Room]")
    new_room = %__MODULE__{name: "Pizza House"}
    {:ok, new_room}
  end

  @doc """
  Start a `GameSupervisor`, e.g. `RicochetRobots.GameSupervisor` which will handle running a game.
  """
  def create_game() do
    GenServer.cast(__MODULE__, {:create_game})
    Logger.debug("[Room: Created Game]")
  end

  @doc """
  Add a user to the room.
  """
  def add_user(user) do
    GenServer.cast(__MODULE__, {:add_user, user})
  end

  @doc """
  Update (replace) a user.

  `key`: the unique key for the user to be replaced.
  """
  def update_user(key) do
    GenServer.cast(__MODULE__, {:update_user, key})
  end

  @doc """
  Remove a user by their unique `key`.
  """
  def remove_user(key) do
    GenServer.cast(__MODULE__, {:remove_user, key})
  end

  @doc """
  Send out a list of all users, to all users.
  """
  def broadcast_scoreboard(registry_key) do
    GenServer.cast(__MODULE__, {:broadcast_scoreboard, registry_key})
  end

  @doc """
  Send a chat message from `user` to all users.
  """
  def user_chat(registry_key, user, message) do
    GenServer.cast(__MODULE__, {:user_chat, registry_key, user, message})
  end

  @doc """
  Send a system chat message to all users.

  * `message`: the content of the message.
  * `special_message = {pid, content}`: if non-empty, a separate message will be sent to a special user (typically the calling user).

  ## Example

      system_chat(state.registry_key, "Say hello to the new user", {self(), "Welcome to the game"})

  """
  def system_chat(registry_key, message, special_message \\ {0, ""}) do
    GenServer.cast(__MODULE__, {:system_chat, registry_key, message, special_message})
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
    users =
      Enum.map(state.users, fn u ->
        if u.unique_key == updated_user.unique_key do
          updated_user
        else
          u
        end
      end)

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
        if pid == pidmatch do
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

defmodule RicochetRobots.SocketHandler do
  @moduledoc """
  Controls the way a user interacts with a `Room` (e.g. chat) or a `Game` (e.g. making a move).
  """
  @behaviour :cowboy_websocket

  require Logger
  alias RicochetRobots.Player, as: Player
  alias RicochetRobots.Room, as: Room
  alias RicochetRobots.Game, as: Game
  alias RicochetRobots.RoomSupervisor, as: RoomSupervisor

  # Terminate if no activity for 1.5 minutes--client should be sending pings.
  @idle_timeout 90000

  # TODO: check if this user is still in the Room, and take over that socket
  @impl true
  def init(request, _state) do
    state = %{
      registry_key: request.path,
      player: %Player{
        username: Player.generate_username(),
        color: Player.generate_color(),
        unique_key: Enum.random(1..1_000_000_000_000)
      }
    }

    Room.add_user(state.player)
    {:cowboy_websocket, request, state, %{idle_timeout: @idle_timeout}}
  end

  @doc "websocket_init: functions that must be called after init()"
  @impl true
  def websocket_init(state) do
    Registry.RicochetRobots
    |> Registry.register(state.registry_key, {})

    {:ok, state}
  end

  # TODO: if it is valid json, forward it along. Otherwise, handle the error
  @doc "Route valid socket messages to other websocket_handle() functions"
  @impl true
  def websocket_handle({:text, json}, state) do
    payload = Poison.decode!(json)
    websocket_handle({:json, payload["action"], payload["content"]}, state)
  end

  @doc "Ping : Message every 90 sec or the connection will be closed. Responds with pong."
  @impl true
  def websocket_handle({:json, "ping", _content}, state) do
    response = Poison.encode!(%{content: "pong", action: "ping"})
    {:reply, {:text, response}, state}
  end

  # TODO: reconsider this functionality
  @doc "Create room: ?"
  @impl true
  def websocket_handle({:json, %{action: "create_room", name: name}}, state) do
    RoomSupervisor.start_link(name)
    Room.system_chat(state.registry_key, "Created room.")
    {:reply, {:text, "success"}, state}
  end

  # TODO: reconsider this functionality
  @impl true
  def websocket_handle({:json, %{action: "join_room"}}, state) do
    # Create the player, have it join the room, add player to state.
    # Max # of players per game check?
    Room.system_chat(state.registry_key, state.player.name <> " joined the room.")
    {:reply, {:text, "success"}, state}
  end

  @doc "new_game : need to send out new board, robots, goals"
  @impl true
  def websocket_handle({:json, "new_game", _content}, state) do
    Logger.debug("[New game] ")
    Game.new_game(state.registry_key)
    Room.system_chat(state.registry_key, "New game started by #{state.player.username}.")
    {:reply, {:text, "success"}, state}
  end

  # TODO: ONLY send board, goals, robots to the new user
  @doc "new_user : need to send out user initialization info to client, and new user message, scoreboard to all users"
  @impl true
  def websocket_handle({:json, "create_user", _content}, state) do
    Logger.debug("[New user]: " <> state[:player].username)

    # seperate message for client that just joined
    Room.system_chat(
      state.registry_key,
      "#{state[:player].username} has joined the game.",
      {self(), "Welcome to Ricochet Robots, #{state[:player].username}!"}
    )

    Room.broadcast_scoreboard(state.registry_key)

    Game.broadcast_visual_board(state.registry_key)
    Game.broadcast_robots(state.registry_key)
    Game.broadcast_goals(state.registry_key)
    Game.broadcast_clock(state.registry_key)

    # send out user initialization info to client
    response = Poison.encode!(%{content: state[:player], action: "update_user"})
    {:reply, {:text, response}, state}
  end

  @doc "new_chatline: need to send out new chatline to all users"
  @impl true
  def websocket_handle({:json, "update_chat", content}, state) do
    Room.user_chat(state.registry_key, state.player, content["msg"])

    # TEMPORARY:
    if content["msg"] == "a" do
      Game.solution_found(state.registry_key, 3, 13, 12345)
    end

    if content["msg"] == "b" do
      Game.award_points(state.registry_key, 3, 13, 12345)
    end

    {:reply, {:text, "success"}, state}
  end

  # TODO: Validate name against other users! Move to player.ex!
  @doc "update_user : need to send validated user info to 1 client and new scoreboard to all"
  @impl true
  def websocket_handle({:json, "update_user", content}, state) do
    Logger.debug("[Update user] " <> state[:player].username <> " --> " <> content["username"])

    old_user = state[:player]

    new_username =
      if String.trim(content["username"]) != "" do
        String.slice(String.trim(content["username"]), 0, 16)
      else
        old_user.username
      end

    new_color =
      if String.trim(content["color"]) != "" do
        String.trim(content["color"])
      else
        old_user.color
      end

    new_user = %{old_user | username: new_username, color: new_color}
    new_state = %{state | player: new_user}

    # send scoreboard to all
    Room.update_user(new_user)
    Room.broadcast_scoreboard(state.registry_key)

    # send client their new user info
    response = Poison.encode!(%{content: content, action: "update_user"})
    {:reply, {:text, response}, new_state}
  end

  # TODO: all
  @doc "submit_movelist : simulate the req. moves"
  @impl true
  def websocket_handle({:json, "submit_movelist", content}, state) do
    Logger.debug("[Move] " <> state[:player].username <> " --> ")

    # TODO: simulate the moves starting with true game board
    ### Game.move("red", "left")
    # TODO: switch to solution mode iff solution found

    new_robots = Game.move_robots(content, state.registry_key, state.player.unique_key)
    response = Poison.encode!(%{content: new_robots, action: "update_robots"})
    {:reply, {:text, response}, state}
  end

  @doc "_ : handle all other JSON data with `action` as unknown."
  @impl true
  def websocket_handle({:json, action, _}, state) do
    Logger.debug("[Unhandled code] " <> action)
    {:reply, {:text, "Got some unhandled code?"}, state}
  end

  @doc "Handle all other messages on their way out to clients."
  @impl true
  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end

  @doc "Callback function from terminated socket."
  @impl true
  def terminate(_reason, _req, state) do
    Room.system_chat(state.registry_key, state.player.username <> " has left.")
    Room.remove_user(state.player.unique_key)
    Room.broadcast_scoreboard(state.registry_key)
    :ok
  end
end

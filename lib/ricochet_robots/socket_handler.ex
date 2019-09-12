defmodule RicochetRobots.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger
  alias RicochetRobots.Player, as: Player
  alias RicochetRobots.Room, as: Room
  alias RicochetRobots.Game, as: Game
  alias RicochetRobots.RoomSupervisor, as: RoomSupervisor

  # Terminate if no activity for 1.5 minutes--client should be sending pings.
  @idle_timeout 10000

  @impl true
  def init(request, _state) do
  #  { visual_board, boundary_board, goals } = build_board()
    state = %{
      registry_key: request.path,
      player: %Player{ username: Player.generate_username(), color: Player.generate_color(), unique_key: Enum.random(1..1000000000000) }
    }
    Room.add_user(state.player)
    {:cowboy_websocket, request, state, %{ idle_timeout: @idle_timeout }}
  end


  # system_user doesn't work?
  # @system_user = %{username: "System", color: "#c6c6c6", score: 0, is_admin: false, is_muted: false}

  # TODO: visual_board (16x16 grid representing CSS squares) should be in parent module
  # TODO: boundary_board (33x33 grid representing open spaces and walls) should be in parent module
  # TODO: robots list should be in parent module
  # TODO: goal-symbols list should be in parent module.
  # TODO: users list should be in parent module AND somehow tied to registry to show active connections...

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

  @doc "ping : Message every 90 sec or the connection will be closed. Responds with pong."
  @impl true
  def websocket_handle({:json, "ping", _content}, state) do
    response = Poison.encode!( %{ content: "pong", action: "ping" } )
    {:reply, {:text, response}, state}
  end

  @impl true
  def websocket_handle({:json, %{action: "create_room", name: name}}, state) do
    RoomSupervisor.start_link(name)
    Room.system_chat(state.registry_key, "Created room.")
    {:reply, {:text, "success"}, state}
  end

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
    Game.new_game()
    Room.system_chat(state.registry_key, "New game started by #{state.player.name}.")
    {:reply, {:text, "success"}, state}
  end






  # TODO: rewrite this when module hierarchy is sorted out!
  @doc "new_user : need to send out user initialization info to client, and new user message, scoreboard to all users"
  @impl true
  def websocket_handle({:json, "create_user", _content}, state) do
    Logger.debug("[New user]: " <> state[:player].username)
    vb = Game.get_board()
    robots = Game.get_robots()
    goals  = Game.get_goals()

    # users = [state[:player] | state[:users] ]
    # json_scoreboard = Poison.encode!( %{ content: users, action: "update_scoreboard" }  )

  #  system_user = %{username: "System", color: "#c6c6c6", score: 0, is_admin: false, is_muted: false}
    new_user_text = state[:player].username <> " has joined the game."
  #  json_new_user_message = Poison.encode!(%{content: %{ user: system_user, msg: new_user_text, kind: 1 }, action: "update_chat" })
   # welcome_text = "Welcome to the game, " <> state[:player].username <> "!"
  #  json_welcome_message = Poison.encode!(%{content: %{ user: system_user, msg: welcome_text, kind: 1 }, action: "update_chat" })

    json_board  = Poison.encode!(%{ action: "update_board", content: vb } )
    json_robots = Poison.encode!(%{ action: "update_robots", content: robots } )
    json_goals  = Poison.encode!(%{ action: "update_goals", content: goals } )

    Registry.RicochetRobots
    |> Registry.dispatch(state.registry_key, fn(entries) ->
      for {pid, _} <- entries do
    #    if pid != self() do
      #    Process.send(pid, json_scoreboard, [])
    #    else
      #    Process.send(pid, json_scoreboard, [])
          Process.send(pid, json_board, [])
          Process.send(pid, json_robots, [])
          Process.send(pid, json_goals, [])
    #    end
      end
    end)

    Room.system_chat(state.registry_key, new_user_text)
    Room.get_scoreboard(state.registry_key)

    # send out user initialization info to client
    response = Poison.encode!( %{ content: state[:player], action: "update_user" }  )
    {:reply, {:text, response}, state}
  end


  @doc "new_chatline: need to send out new chatline to all users"
  @impl true
  def websocket_handle({:json, "update_chat", content}, state) do
 #   response = Poison.encode!( %{ content: content, action: "update_chat" }  )
 #   Logger.debug("[Chatline] "<>content["user"]["username"]<>": " <> content["msg"])

    Room.user_chat(state.registry_key, state.player, content["msg"])

    {:reply, {:text, "success"}, state}
  end


  # TODO: Validate name against other users!
  @doc "update_user : need to send validated user info to 1 client and new scoreboard to all"
  @impl true
  def websocket_handle({:json, "update_user", content}, state) do
    Logger.debug("[Update user] " <> state[:player].username <> " --> " <> content["username"])

    old_user = state[:player]
    new_username = if String.trim( content["username"] ) != "" do String.trim( content["username"] ) else old_user.username end
    new_color = if String.trim( content["color"] ) != "" do String.trim( content["color"] ) else old_user.color end
    new_user = %{old_user | username: new_username, color: new_color}
    new_state = %{state | user: new_user}

    # send scoreboard to all
    Registry.RicochetRobots
    |> Registry.dispatch(state.registry_key, fn(entries) ->
      for {pid, _} <- entries do
        users = [new_state[:player] | new_state[:users] ]
        response = Poison.encode!( %{ content: users, action: "update_scoreboard" }  )
        Process.send(pid, response, [])
      end
    end)

    # send client their new user info
    response = Poison.encode!( %{ content: content, action: "update_user" }  )
    {:reply, {:text, response}, new_state }
  end


  @doc "_ : handle all other action_codes as unknown."
  @impl true
  def websocket_handle({:json, action, _}, state) do
    Logger.debug("[Unhandled code] " <> action )
    {:reply, {:text, "Got some unhandled code?"}, state}
  end


  @doc "websocket_info handles some messages on their way out..."
  @impl true
  def websocket_info({:json, action, content}, state) do
      Logger.debug("[Send] " <> action )
      data = Poison.encode!( %{ content: content, action: action } )
      {:reply, {:text, data}, state}
    end

  @doc "Handle all other messages on their way out to clients."
  @impl true
  def websocket_info(info, state) do
  #  IO.inspect(info)
    {:reply, {:text, info}, state}
  end

  @impl true
  def terminate(_reason, _req, state) do
    Room.remove_user(state.player.unique_key)
    Room.get_scoreboard(state.registry_key)
    :ok
  end





#   @impl true
#   def websocket_handle({:json, %{action: "submit_solution", solution: solution}}, state) do
#  #   Game.submit_solution(solution)
#  #   Room.system_chat(state.registry_key, "Solution submitted by #{state.player.name}")
#     {:reply, {:text, "success"}, state}
#   end

#   @impl true
#   def websocket_handle({:json, %{action: "send_chat_message", message: message}}, state) do
#     Room.user_chat(state.registry_key, state.player, message)
#     {:reply, {:text, "success"}, state}
#   end



end

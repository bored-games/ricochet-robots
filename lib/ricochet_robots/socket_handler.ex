defmodule RicochetRobots.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger
  alias RicochetRobots.Room, as: Room
  alias RicochetRobots.Game, as: Game
  alias RicochetRobots.RoomSupervisor, as: RoomSupervisor

  # Terminate if no activity for 1.5 minutes--client should be sending pings.
  @idle_timeout 90000

  @impl true
  def init(request, _state) do
  #  { visual_board, boundary_board, goals } = build_board()
    state = %{
      registry_key: request.path,
      player: %RicochetRobots.Player{username: RicochetRobots.Player.generate_username()},
  #    visual_board: visual_board,
  #    boundary_board: boundary_board,
  #    robots: get_robots(),
  #    goals: goals,
      users: [ %{ username: "art", color: "#e0a85e", score: 16, owner: false, muted: false },
      %{ username: "simon", color: "#95e05e", score: 25, owner: false, muted: false },
      %{ username: "pete", color: "#5eb7e0", score: 50, owner: false, muted: true },
      %{ username: "arlo", color: "#e05e9b", score: 8, owner: false, muted: false }]

      }

    {:cowboy_websocket, request, state, %{ idle_timeout: @idle_timeout }}
  end


  # system_user doesn't work?
  # @system_user = %{username: "System", color: "#fff", score: 0, owner: false, muted: false}

  # TODO: visual_board (16x16 grid representing CSS squares) should be in parent module
  # TODO: boundary_board (33x33 grid representing open spaces and walls) should be in parent module
  # TODO: robots list should be in parent module
  # TODO: goal-symbols list should be in parent module.
  # TODO: users list should be in parent module AND somehow tied to registry to show active connections...

  @impl true
  @doc "websocket_init: functions that must be called after init()"
  def websocket_init(state) do
    Registry.RicochetRobots
    |> Registry.register(state.registry_key, {})

    {:ok, state}
  end

  # TODO: if it is valid json, forward it along. Otherwise, handle the error
  @impl true
  @doc "Route valid socket messages to other websocket_handle() functions"
  def websocket_handle({:text, json}, state) do
    payload = Poison.decode!(json)
    websocket_handle({:json, payload["code"], payload["content"]}, state)
  end

  @impl true
  @doc "ping : Message every 90 sec or the connection will be closed. Responds with pong."
  def websocket_handle({:json, 001, _content}, state) do
    Logger.debug("[Ping] ")
    response = Poison.encode!( %{ content: "pong!", code: 001 } )
    {:reply, {:text, response}, state}
  end

  @impl true
  def websocket_handle({:json, %{action: "create_room", name: name}}, state) do
    RoomSupervisor.start_link(name)
    Room.log_to_chat("Created room.")
    {:reply, {:text, "success"}, state}
  end

  @impl true
  def websocket_handle({:json, %{action: "join_room"}}, state) do
    # Create the player, have it join the room, add player to state.
    # Max # of players per game check?
    Room.log_to_chat(state.player.name <> " joined the room.")
    {:reply, {:text, "success"}, state}
  end

  @doc "new_game : need to send out new board, robots, goals"
  @impl true
  def websocket_handle({:json, 100, _content}, state) do
    Logger.debug("[New game] ")
    Game.new_game()
    Room.log_to_chat("New game started by #{state.player.name}.")
    {:reply, {:text, "success"}, state}
  end






  # TODO: rewrite this when module hierarchy is sorted out!
  @doc "new_user : need to send out user initialization info to client,
  and new user message, scoreboard to all users"
  @impl true
  def websocket_handle({:json, 200, _content}, state) do
    Logger.debug("[New user]: " <> state[:user].username)
    users = [state[:user] | state[:users] ]
    json_scoreboard = Poison.encode!( %{ content: users, code: 200 }  )

    # send out users list to all
    # send out a system chat message
    system_user = %{username: "System", color: "#fff", score: 0, owner: false, muted: false}
    new_user_text = state[:user].username <> " has joined the game."
    json_new_user_message = Poison.encode!(%{content: %{ user: system_user, msg: new_user_text, kind: 1 }, code: 202 })
    welcome_text = "Welcome to the game, " <> state[:user].username <> "!"
    json_welcome_message = Poison.encode!(%{content: %{ user: system_user, msg: welcome_text, kind: 1 }, code: 202 })

    test = for {_k, v} <- state[:visual_board], do: (for {_kk, vv} <- v, do: vv)
    json_board  = Poison.encode!(%{ code: 100, content: test } )
    json_robots = Poison.encode!(%{ code: 101, content: state[:robots] } )
    json_goals  = Poison.encode!(%{ code: 102, content: state[:goals] } )

    Registry.RicochetRobots
    |> Registry.dispatch(state.registry_key, fn(entries) ->
      for {pid, _} <- entries do
        if pid != self() do
          Process.send(pid, json_scoreboard, [])
          Process.send(pid, json_new_user_message, [])
        else
          Process.send(pid, json_scoreboard, [])
          Process.send(pid, json_board, [])
          Process.send(pid, json_robots, [])
          Process.send(pid, json_goals, [])

          Process.send(pid, json_welcome_message, [])
        end
      end
    end)

    # send out user initialization info to client
    response = Poison.encode!( %{ content: state[:user], code: 201 }  )
    {:reply, {:text, response}, state}
  end


  @doc "new_chatline: need to send out new chatline to all users"
  @impl true
  def websocket_handle({:json, 202, content}, state) do
    response = Poison.encode!( %{ content: content, code: 202 }  )
    Logger.debug("[Chatline] "<>content["user"]["username"]<>": " <> content["msg"])

    Room.send_message(state.player, content)

    # send chat message to all
    Registry.RicochetRobots
    |> Registry.dispatch(state.registry_key, fn(entries) ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:reply, {:text, "success"}, state}
  end


  # TODO: Validate name against other users!
  @doc "update_user : need to send validated user info to 1 client and new scoreboard to all"
  @impl true
  def websocket_handle({:json, 201, content}, state) do
    Logger.debug("[Update user] " <> state[:user].username <> " --> " <> content["username"])

    old_user = state[:user]
    new_username = if String.trim( content["username"] ) != "" do String.trim( content["username"] ) else old_user.username end
    new_color = if String.trim( content["color"] ) != "" do String.trim( content["color"] ) else old_user.color end
    new_user = %{old_user | username: new_username, color: new_color}
    new_state = %{state | user: new_user}

    # send scoreboard to all
    Registry.RicochetRobots
    |> Registry.dispatch(state.registry_key, fn(entries) ->
      for {pid, _} <- entries do
        users = [new_state[:user] | new_state[:users] ]
        response = Poison.encode!( %{ content: users, code: 200 }  )
        Process.send(pid, response, [])
      end
    end)

    # send client their new user info
    response = Poison.encode!( %{ content: content, code: 201 }  )
    {:reply, {:text, response}, new_state }
  end


  @doc "_ : handle all other opcodes as unknown."
  @impl true
  def websocket_handle({:json, opcode, _}, state) do
    Logger.debug("[Unhandled code] " <> Integer.to_string(opcode) )
    {:reply, {:text, "Got some unhandled code?"}, state}
  end


  @doc "websocket_info handles some messages on their way out..."
  @impl true
  def websocket_info({:json, opcode, content}, state) do
      Logger.debug("[Send] " <> Integer.to_string(opcode) )
      data = Poison.encode!( %{ content: content, code: opcode } )
      {:reply, {:text, data}, state}
    end

  @doc "Handle all other messages on their way out to clients."
  @impl true
  def websocket_info(info, state) do
  #  IO.inspect(info)
    {:reply, {:text, info}, state}
  end








#   @impl true
#   def websocket_handle({:json, %{action: "submit_solution", solution: solution}}, state) do
#  #   Game.submit_solution(solution)
#  #   Room.log_to_chat("Solution submitted by #{state.player.name}")
#     {:reply, {:text, "success"}, state}
#   end

#   @impl true
#   def websocket_handle({:json, %{action: "send_chat_message", message: message}}, state) do
#     Room.send_message(state.player, message)
#     {:reply, {:text, "success"}, state}
#   end



end

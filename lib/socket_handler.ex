defmodule Player do
  defstruct username: nil, color: "#cccccc", score: 0, owner: false, muted: false, joined: nil
end


defmodule RicochetRobots.SocketHandler do
  @behaviour :cowboy_websocket
  @timeout 90000 # 90 sec. socket timeout

  import Bitwise
  require Logger
  require Player

  # doesn't work?
  # @system_user = %{username: "System", color: "#fff", score: 0, owner: false, muted: false}

  # TODO: visual_board (16x16 grid representing CSS squares) should be in parent module
  # TODO: boundary_board (33x33 grid representing open spaces and walls) should be in parent module
  # TODO: robots list should be in parent module
  # TODO: goal-symbols list should be in parent module.
  # TODO: users list should be in parent module AND somehow tied to registry to show active connections...
  def init(request, _state) do
    { visual_board, boundary_board, goals } = build_board()
    state = %{ registry_key: request.path,
               visual_board: visual_board,
               boundary_board: boundary_board,
               robots: get_robots(),
               goals: goals,
               user: new_user([]),
               users: [ %{ username: "art", color: "#e0a85e", score: 16, owner: false, muted: false },
               %{ username: "simon", color: "#95e05e", score: 25, owner: false, muted: false },
               %{ username: "pete", color: "#5eb7e0", score: 50, owner: false, muted: true },
               %{ username: "arlo", color: "#e05e9b", score: 8, owner: false, muted: false }] }

    {:cowboy_websocket, request, state, %{ idle_timeout: @timeout } }
  end

  @doc "websocket_init: functions that must be called after init()"
  def websocket_init(state) do
    Registry.RicochetRobots
    |> Registry.register(state.registry_key, {})

    {:ok, state}
  end

  @doc "Route valid socket messages to other websocket_handle() functions"
  # TODO: if it is valid json, forward it along. Otherwise, handle the error
  def websocket_handle({:text, json}, state) do
    payload = Poison.decode!(json)
    websocket_handle({:json, payload["code"], payload["content"]}, state)
  end

  @doc "ping : Message every 90 sec or the connection will be closed. Responds with pong."
  def websocket_handle({:json, 001, _content}, state) do
    Logger.debug("[Ping] ")
    response = Poison.encode!( %{ content: "pong!", code: 001 } )
    {:reply, {:text, response}, state}
  end

  @doc "new_game : need to send out new board, robots, goals"
  def websocket_handle({:json, 100, _content}, state) do
    Logger.debug("[New game] ")

    # TODO: Actually make a new game!

    # send to all: new board, robots, goals
    test = for {_k, v} <- state[:visual_board], do: (for {_kk, vv} <- v, do: vv)
    json_board  = Poison.encode!(%{ code: 100, content: test } )
    json_robots = Poison.encode!(%{ code: 101, content: state[:robots] } )
    json_goals  = Poison.encode!(%{ code: 102, content: state[:goals] } )
    system_user = %{username: "System", color: "#c6c6c6", score: 0, owner: false, muted: false}
    json_msg    = Poison.encode!(%{ code: 202, content: %{ user: system_user, msg: "A new game has begun.", kind: 1 } } )
    Registry.RicochetRobots
    |> Registry.dispatch(state.registry_key, fn(entries) ->
      for {pid, _} <- entries do
        Process.send(pid, json_board, [])
        Process.send(pid, json_robots, [])
        Process.send(pid, json_goals, [])
        Process.send(pid, json_msg, [])
      end
    end)

    # don't know what to send here.
    response = Poison.encode!( %{ content: "pong!", code: 001 }  )
    {:reply, {:text, response}, state}
  end

  @doc "new_user : need to send out user initialization info to client,
  and new user message, scoreboard to all users"
  # TODO: rewrite this when module hierarchy is sorted out!
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
  def websocket_handle({:json, 202, content}, state) do
    response = Poison.encode!( %{ content: content, code: 202 }  )
    Logger.debug("[Chatline] "<>content["user"]["username"]<>": " <> content["msg"])

    # send chat message to all except client...
    Registry.RicochetRobots
    |> Registry.dispatch(state.registry_key, fn(entries) ->
      for {pid, _} <- entries do
        if pid != self() do
          Process.send(pid, response, [])
        end
      end
    end)

    # send chat message to client as well
    {:reply, {:text, response}, state}
  end


  # TODO: Validate name against other users!
  @doc "update_user : need to send validated user info to 1 client and new scoreboard to all"
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
  def websocket_handle({:json, opcode, _}, state) do
    Logger.debug("[Unhandled code] " <> Integer.to_string(opcode) )
    {:reply, {:text, "Got some unhandled code?"}, state}
  end


  @doc "websocket_info handles some messages on their way out..."
  def websocket_info({:json, opcode, content}, state) do
      Logger.debug("[Send] " <> Integer.to_string(opcode) )
      data = Poison.encode!( %{ content: content, code: opcode } )
      {:reply, {:text, data}, state}
    end

  @doc "Handle all other messages on their way out to clients."
  def websocket_info(info, state) do
  #  IO.inspect(info)
    {:reply, {:text, info}, state}
  end



  @doc "Return a new user with unique, randomized name"
  # TODO: verify this doesn't permit duplicate names after switching datastructures
  @spec new_user([Player]) :: Player
  def new_user(users) do
    arr1 = ["Robot", "Doctor", "Puzzle", "Automaton", "Data", "Buzz", "Infinity", "Cyborg", "Android", "Electro", "Robo", "Battery", "Beep" ];
    arr2 = ["Lover", "Love", "Power", "Clicker", "Friend", "Genius", "Beep", "Boop", "Sim", "Asimov", "Talos" ];
    arr3 = ["69", "420", "XxX", "2001", "", "", "", "", "", "", "", "", ""];
    username = Enum.random(arr1) <> Enum.random(arr2) <> Enum.random(arr3)
    color = Enum.random(["#707070", "#e05e5e", "#e09f5e", "#e0e05e", "#9fe05e", "#5ee05e", "#5ee09f", "#5ee0e0", "#5e9fe0", "#5e5ee0", "#9f5ee0", "#e05ee0", "#e05e9f", "#b19278", "#e0e0e0"])

    # Better way to verify username is not in use?
    if Enum.member?( Enum.map(users, &Map.get(&1, :username)), username) do
      new_user(users)
    else
      {:ok, datestr} = DateTime.now("Etc/UTC")
      %Player{username: username, color: color, joined: datestr }
    end
  end





  # TODO: use these or get rid of them? When is a type better than a defstruct?
  @typedoc "User: { username: String, color: String, score: integer }"
  @type user_t :: %{ username: String.t, color: String.t, score: integer, datestr: DateTime.t }

  @typedoc "Position: { row: Integer, col: Integer }"
  @type position_t :: {integer, integer}

  @typedoc "Position2: { row: Integer, col: Integer }"
  @type position2_t :: %{x: integer, y: integer}

  @typedoc "Robot: { pos: position, color: String }"
  @type robot_t :: %{pos: position2_t, color: String.t, moves: [ String.t ]}

  @typedoc "Goal: { pos: position, symbol: String, active: boolean }"
  @type goal_t :: %{pos: position2_t, symbol: String.t, active: boolean }


  @doc "Return 5 robots in unique, random positions, avoiding the center 4 squares."
  @spec get_robots() :: [ robot_t ]
  def get_robots() do
    robots = add_robot("red", [])
    robots = add_robot("green", robots)
    robots = add_robot("blue", robots)
    robots = add_robot("yellow", robots)
    add_robot("silver", robots)
  end

  # Given color, list of previous robots, add a single 'color' robot to an unoccupied square
  @spec add_robot( String.t , [ robot_t] ) :: [ robot_t ]
  defp add_robot(color, robots) do
    open_squares = [0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15]
    rlist = rand_unique_pairs(open_squares, open_squares, robots)
    [ %{ pos: List.first(rlist), color: color, moves: ["up", "left", "down", "right"] } | robots ]
  end

  @doc "Return a randomized boundary board, its visual map, and corresponding goal positions."
  @spec build_board() :: { map, map, [ goal_t ] }
  def build_board() do
    goal_symbols = Enum.shuffle(["RedMoon","GreenMoon","BlueMoon","YellowMoon","RedPlanet","GreenPlanet","BluePlanet","YellowPlanet","GreenCross","RedCross","BlueCross","YellowCross","RedGear","GreenGear","BlueGear","YellowGear"])
    goal_active = Enum.shuffle([true,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false])

    # I'm so sorry
    a = %{
      0  => %{ 0=>1, 1=>1, 2=>1, 3=>1, 4=>1, 5=>1, 6=>1, 7=>1, 8=>1, 9=>1,10=>1,11=>1,12=>1,13=>1,14=>1,15=>1,16=>1,17=>1,18=>1,19=>1,20=>1,21=>1,22=>1,23=>1,24=>1,25=>1,26=>1,27=>1,28=>1,29=>1,30=>1,31=>1,32=>1},
      1  => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      2  => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      3  => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      4  => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      5  => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      6  => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      7  => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      8  => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      9  => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      10 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      11 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      12 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      13 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      14 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>1,15=>1,16=>1,17=>1,18=>1,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      15 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>1,15=>1,16=>1,17=>1,18=>1,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      16 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>1,15=>1,16=>1,17=>1,18=>1,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      17 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>1,15=>1,16=>1,17=>1,18=>1,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      18 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>1,15=>1,16=>1,17=>1,18=>1,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      19 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      20 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      21 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      22 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      23 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      24 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      25 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      26 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      27 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      28 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      29 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      30 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      31 => %{ 0=>1, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0,16=>0,17=>0,18=>0,19=>0,20=>0,21=>0,22=>0,23=>0,24=>0,25=>0,26=>0,27=>0,28=>0,29=>0,30=>0,31=>0,32=>1},
      32 => %{ 0=>1, 1=>1, 2=>1, 3=>1, 4=>1, 5=>1, 6=>1, 7=>1, 8=>1, 9=>1,10=>1,11=>1,12=>1,13=>1,14=>1,15=>1,16=>1,17=>1,18=>1,19=>1,20=>1,21=>1,22=>1,23=>1,24=>1,25=>1,26=>1,27=>1,28=>1,29=>1,30=>1,31=>1,32=>1}
    }

    # two | per board edge, with certain spaces avoided
    a = put_in a[1][ Enum.random([4,6,8,10,12,14]) ], 1
    a = put_in a[1][ Enum.random([18,20,22,24,26,28]) ], 1
    a = put_in a[31][ Enum.random([4,6,8,10,12,14]) ], 1
    a = put_in a[31][ Enum.random([18,20,22,24,26,28]) ], 1
    a = put_in a[ Enum.random([4,6,8,10,12,14]) ][1], 1
    a = put_in a[ Enum.random([18,20,22,24,26,28]) ][1], 1
    a = put_in a[ Enum.random([4,6,8,10,12,14]) ][31], 1
    a = put_in a[ Enum.random([18,20,22,24,26,28]) ][31], 1

    # TODO: ensure L's aren't too close to |'s?
    # four "L"s per quadrant
    rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [2, 4, 6, 8, 10, 12], [])
    {a, goals} = add_L1(a, List.first(rlist), Enum.fetch!(goal_symbols, 0), Enum.fetch!(goal_active, 0), [] )
    rlist = rand_distant_pairs([2, 4, 6, 8, 10, 12], [2, 4, 6, 8, 10, 12], rlist)
    {a, goals} = add_L2(a, List.first(rlist), Enum.fetch!(goal_symbols, 1), Enum.fetch!(goal_active, 1), goals )
    rlist = rand_distant_pairs([2, 4, 6, 8, 10, 12], [4, 6, 8, 10, 12, 14], rlist)
    {a, goals} = add_L3(a, List.first(rlist), Enum.fetch!(goal_symbols, 2), Enum.fetch!(goal_active, 2), goals )
    rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [4, 6, 8, 10, 12, 14], rlist)
    {a, goals} = add_L4(a, List.first(rlist), Enum.fetch!(goal_symbols, 3), Enum.fetch!(goal_active, 3), goals )
    ############################################
    rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [18, 20, 22, 24, 26, 28], rlist)
    {a, goals} = add_L1(a, List.first(rlist), Enum.fetch!(goal_symbols, 4), Enum.fetch!(goal_active, 4), goals )
    rlist = rand_distant_pairs([2, 4, 6, 8, 10, 12], [18, 20, 22, 24, 26, 28], rlist)
    {a, goals} = add_L2(a, List.first(rlist), Enum.fetch!(goal_symbols, 5), Enum.fetch!(goal_active, 5), goals )
    rlist = rand_distant_pairs([2, 4, 6, 8, 10, 12], [20, 22, 24, 26, 28, 30], rlist)
    {a, goals} = add_L3(a, List.first(rlist), Enum.fetch!(goal_symbols, 6), Enum.fetch!(goal_active, 6), goals )
    rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [20, 22, 24, 26, 28, 30], rlist)
    {a, goals} = add_L4(a, List.first(rlist), Enum.fetch!(goal_symbols, 7), Enum.fetch!(goal_active, 7), goals )
    ############################################
    rlist = rand_distant_pairs([20, 22, 24, 26, 28, 30], [2, 4, 6, 8, 10, 12], rlist)
    {a, goals} = add_L1(a, List.first(rlist), Enum.fetch!(goal_symbols, 8), Enum.fetch!(goal_active, 8), goals )
    rlist = rand_distant_pairs([18, 20, 22, 24, 26, 28], [2, 4, 6, 8, 10, 12], rlist)
    {a, goals} = add_L2(a, List.first(rlist), Enum.fetch!(goal_symbols, 9), Enum.fetch!(goal_active, 9), goals )
    rlist = rand_distant_pairs([18, 20, 22, 24, 26, 28], [4, 6, 8, 10, 12, 14], rlist)
    {a, goals} = add_L3(a, List.first(rlist), Enum.fetch!(goal_symbols, 10), Enum.fetch!(goal_active, 10), goals )
    rlist = rand_distant_pairs([20, 22, 24, 26, 28, 30], [4, 6, 8, 10, 12, 14], rlist)
    {a, goals} = add_L4(a, List.first(rlist), Enum.fetch!(goal_symbols, 11), Enum.fetch!(goal_active, 11), goals )
    ############################################
    rlist = rand_distant_pairs([20, 22, 24, 26, 28, 30], [18, 20, 22, 24, 26, 28], rlist)
    {a, goals} = add_L1(a, List.first(rlist), Enum.fetch!(goal_symbols, 12), Enum.fetch!(goal_active, 12), goals )
    rlist = rand_distant_pairs([18, 20, 22, 24, 26, 28], [18, 20, 22, 24, 26, 28], rlist)
    {a, goals} = add_L2(a, List.first(rlist), Enum.fetch!(goal_symbols, 13), Enum.fetch!(goal_active, 13), goals )
    rlist = rand_distant_pairs([18, 20, 22, 24, 26, 28], [20, 22, 24, 26, 28, 30], rlist)
    {a, goals} = add_L3(a, List.first(rlist), Enum.fetch!(goal_symbols, 14), Enum.fetch!(goal_active, 14), goals )
    rlist = rand_distant_pairs([20, 22, 24, 26, 28, 30], [20, 22, 24, 26, 28, 30], rlist)
    {a, goals} = add_L4(a, List.first(rlist), Enum.fetch!(goal_symbols, 15), Enum.fetch!(goal_active, 15), goals )
    ############################################

    # visual_map init:
    b = %{
      0  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      1  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      2  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      3  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      4  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      5  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      6  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      7  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      8  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      9  => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      10 => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      11 => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      12 => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      13 => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      14 => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
      15 => %{ 0=>0, 1=>0, 2=>0, 3=>0, 4=>0, 5=>0, 6=>0, 7=>0, 8=>0, 9=>0,10=>0,11=>0,12=>0,13=>0,14=>0,15=>0},
    }
    b = populate_rows(a, b, 15)

    # put in final special blocks into center 4 squares
    b = put_in b[7][7], 256
    b = put_in b[7][8], 257
    b = put_in b[8][7], 258
    b = put_in b[8][8], 259

    { b, a, goals }
  end

  # Add L
  @spec add_L1( map, {integer, integer}, String.t, boolean, [ goal_t] ) :: { map, [goal_t] }
  defp add_L1(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in a[row][col], 1
    a = put_in a[row][col+1], 1
    a = put_in a[row-1][col], 1
    { a, [ %{pos: %{y: div(row-1, 2), x: div(col+1, 2)}, symbol: goal_string, active: goal_active } | goals ] }
  end

  # Add L, rotated 90 deg CW
  @spec add_L2( map, {integer, integer}, String.t, boolean, [ goal_t] ) :: { map, [goal_t] }
  defp add_L2(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in a[row][col], 1
    a = put_in a[row][col+1], 1
    a = put_in a[row+1][col], 1
    { a, [ %{pos: %{y: div(row+1, 2), x: div(col+1, 2)}, symbol: goal_string, active: goal_active } | goals ] }
  end

  # Add L, rotated 180 deg
  @spec add_L3( map, {integer, integer}, String.t, boolean, [ goal_t] ) :: { map, [goal_t] }
  defp add_L3(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in a[row][col], 1
    a = put_in a[row][col-1], 1
    a = put_in a[row+1][col], 1
    { a, [ %{pos: %{y: div(row+1, 2), x: div(col-1, 2)}, symbol: goal_string, active: goal_active } | goals ] }
  end

  # Add L, rotated 270 deg CW
  @spec add_L4( map, {integer, integer}, String.t, boolean, [ goal_t] ) :: { map, [goal_t] }
  defp add_L4(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in a[row][col], 1
    a = put_in a[row][col-1], 1
    a = put_in a[row-1][col], 1
    { a, [ %{pos: %{y: div(row-1, 2), x: div(col-1, 2)}, symbol: goal_string, active: goal_active } | goals ] }
  end

  # Populate a row of visual_board (b) based on boundary board (a)
  # TODO: how do Elixir people usually write this + the next function?
  defp populate_rows(a, b, row) when row <= 0 do
    populate_cols(a, b, row, 15)
  end

  defp populate_rows(a, b, row) do
    b = populate_cols(a, b, row, 15)
    populate_rows(a, b, row-1)
  end

  #TOP = 1    RIG = 2    BOT = 4    LEF = 8
  #TRT = 16   BRT = 32   BLT = 64   TLT = 128
  # Find the bordering cells of b[row][col] in the boundary_board (a) and stuff in the correct integer representation for frontend presentation
  defp populate_cols(a, b, row, col) when col <= 0 do
    cc = (2*col+1)
    rr = (2*row+1)
    put_in b[row][col], ( (a[rr-1][cc]*1) ||| (a[rr][cc+1]*2) ||| (a[rr+1][cc]*4) ||| (a[rr][cc-1]*8) ||| (a[rr-1][cc+1]*16) ||| (a[rr+1][cc+1]*32) ||| (a[rr+1][cc-1]*64) ||| (a[rr-1][cc-1]*128) )
  end
  defp populate_cols(a, b, row, col) do
    cc = (2*col+1)
    rr = (2*row+1)
    b = put_in b[row][col], ( (a[rr-1][cc]*1) ||| (a[rr][cc+1]*2) ||| (a[rr+1][cc]*4) ||| (a[rr][cc-1]*8) ||| (a[rr-1][cc+1]*16) ||| (a[rr+1][cc+1]*32) ||| (a[rr+1][cc-1]*64) ||| (a[rr-1][cc-1]*128) )
    populate_cols(a, b, row, col-1)
  end

  # TODO: write this with position_t type
  @doc "Given a list of {int, int} pairs not to repeat, and two arrays to choose new tuples from, return a list with a new unique tuple"
  @spec rand_unique_pairs([integer], [integer], [ %{x: integer, y: integer}]) :: [ %{x: integer, y: integer} ]
  def rand_unique_pairs(rs, cs, avoids, cnt \\ 0) do
    rand_pair = %{x: Enum.random(cs), y: Enum.random(rs)}
    if cnt > 50 do
      [ {-1, -1} |avoids ]
    else
      if (rand_pair in avoids) do
        rand_unique_pairs(rs, cs, avoids, cnt+1)
      else
        [ rand_pair | avoids ]
      end
    end
  end

  # TODO: write this with position_t type
  @doc "Given a list of {int, int} pairs to avoid, and two arrays to choose new tuples from, return a list with a new tuple at least 2 distance away"
  @spec rand_distant_pairs([integer], [integer], [{integer, integer}]) :: [{integer, integer}]
  def rand_distant_pairs(rs, cs, avoids, cnt \\ 0) do
    {r, c} = {Enum.random(rs), Enum.random(cs)}
    if cnt > 50 do
      [ {-1, -1} | avoids ]
    else
      if ( Enum.any?(avoids, fn {r1, c1} -> dist_under_2?({r1, c1}, {r, c}) end) ) do
        rand_distant_pairs(rs, cs, avoids, cnt+1)
      else
        [ {r, c} | avoids ]
      end
    end
  end

  # TODO: write this with position_t type
  @doc "Take {x1, y1} and {x2, y2}; is the distance between them more than 2.0 (on condensed board; 4.0 on boundary_board)?"
  @spec dist_under_2?({integer, integer}, {integer, integer}) :: boolean
  def dist_under_2?({x1, y1}, {x2, y2}) do
    ((y1-y2)*(y1-y2) + (x1-x2)*(x1-x2)) <= 16.0
  end

end


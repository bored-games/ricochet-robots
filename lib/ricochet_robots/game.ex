defmodule RicochetRobots.Game do
  use GenServer
  import Bitwise
  require Logger
  alias RicochetRobots.Room, as: Room

  defstruct boundary_board: nil,
            visual_board: nil,
            robots: [],
            goals: [],
            # time in seconds after a solution is found
            setting_countdown: 60,
            # 1-robot solutions below this value should not count
            setting_min_moves: 3,
            # new board generated ever `n` many puzzles
            setting_puzzles_before_new: 10,
            # new board generated after this many more puzzles
            current_puzzles_until_new: 10,
            # current countdown: at 0, best solution wins
            current_countdown: 60,
            # current timer
            current_timer: 0,
            # boolean: has solution been found
            solution_found: false,
            # number of moves in current best solution
            solution_moves: 0,
            # number of robots in current best solution
            solution_robots: 0,
            # user id of current best solution
            solution_uid: 0

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.debug("[Game: Started game]")
    :timer.send_interval(1000, :timerevent)
    {visual_board, boundary_board, goals} = populate_board()
    robots = populate_robots()

    state = %__MODULE__{
      boundary_board: boundary_board,
      visual_board: visual_board,
      goals: goals,
      robots: robots
    }

    {:ok, state}
  end

  @doc "New game (new boards, new robot positions, new goal positions)."
  def new_game(registry_key) do
    Logger.debug("[Game: New game]")
    GenServer.cast(__MODULE__, {:new_game})
    broadcast_visual_board(registry_key)
    broadcast_robots(registry_key)
    broadcast_goals(registry_key)
  end

  @doc "Send out the current board."
  def broadcast_visual_board(registry_key) do
    GenServer.cast(__MODULE__, {:broadcast_visual_board, registry_key})
  end

  @doc "Send out the current robot positions."
  def broadcast_robots(registry_key) do
    GenServer.cast(__MODULE__, {:broadcast_robots, registry_key})
  end

  @doc "Send out the current goal positions, and the active goal symbol."
  def broadcast_goals(registry_key) do
    GenServer.cast(__MODULE__, {:broadcast_goals, registry_key})
  end

  @doc "Send out the current goal positions, and the active goal symbol."
  def broadcast_clock(registry_key) do
    GenServer.cast(__MODULE__, {:broadcast_clock, registry_key})
  end

  @doc ""
  def solution_found(registry_key, num_robots, num_moves, uid) do
    GenServer.cast(__MODULE__, {:solution_found, registry_key, num_robots, num_moves, uid})
  end

  @doc ""
  def award_points(registry_key, num_robots, num_moves, uid) do
    GenServer.cast(__MODULE__, {:award_points, registry_key, num_robots, num_moves, uid})
  end


  @doc "Given a list of moves, move the robots; then calculate_new_moves(); return the final positions of the robots and their new moves"
  def move_robots(moves) do
    GenServer.call(__MODULE__, {:move_robots, moves})
  end

  #
  @impl true
  def handle_call({:move_robots, moves}, _from, state) do
    new_robots = make_move(state.robots, state.boundary_board, moves)
    {:reply, new_robots, state}
  end

  # Out of moves -- TODO: check if solution was found
  defp make_move(robots, _board, []) do
    robots
    #calculate_moves(robots)
  end

  defp make_move(robots, board, [headmove | tailmoves]) do
    color = headmove["color"]
    direction = headmove["direction"]
    Logger.debug("[Moving #{color} robot #{direction}]")
    moved_robot = Enum.find(robots, nil, fn r -> r.color == color end)
    %{x: rx, y: ry} = moved_robot[:pos]

    # TODO: clean up?
    new_pos = case direction do
      "up" ->
        %{x: rx, y: Enum.max([get_wall_blocked_indices(moved_robot[:pos], :up, board) | get_robot_blocked_indices(moved_robot[:pos], :up, robots)])}
      "down" ->
        %{x: rx, y: Enum.min([get_wall_blocked_indices(moved_robot[:pos], :down, board) | get_robot_blocked_indices(moved_robot[:pos], :down, robots)])} # min([ wall-blocked, robot-blocked])
      "left" ->
        %{x: Enum.max([get_wall_blocked_indices(moved_robot[:pos], :left, board) | get_robot_blocked_indices(moved_robot[:pos], :left, robots)]), y: ry}
      "right" ->
        %{x: Enum.min([get_wall_blocked_indices(moved_robot[:pos], :right, board) | get_robot_blocked_indices(moved_robot[:pos], :right, robots)]), y: ry}
      _ ->
        %{x: rx, y: ry}
    end

    moved_robot = %{moved_robot | pos: new_pos}
    new_robots = Enum.map(robots, fn r -> if r.color == color do moved_robot else r end end)
    make_move(new_robots, board, tailmoves)
  end

  #@doc "Given a robot position and direction, return the relevant index of the first wall the robot will hit."
  defp get_wall_blocked_indices(vb_pos, direction, board) do
    bb_pos = %{row: round(2*vb_pos[:y] + 1), col: round(2*vb_pos[:x] + 1)}
    case direction do
      :up ->
        Enum.max( Enum.map( Enum.filter( (for z <- 0..32, into: [], do: {z, board[z][bb_pos[:col]]}), fn {a, b} -> (b == 1 && a < bb_pos[:row]) end), fn {a, _b} -> a end ) )/2 # max( all cols where col < bb_pos[:col] and cell == 1   )/2
      :down ->
        Enum.min( Enum.map( Enum.filter( (for z <- 0..32, into: [], do: {z, board[z][bb_pos[:col]]}), fn {a, b} -> (b == 1 && a > bb_pos[:row]) end), fn {a, _b} -> a end ) )/2 - 1 # min( all rows where row > bb_pos[:row] and cell == 1   )/2-1
      :left ->
        Enum.max( Enum.map( Enum.filter( board[bb_pos[:row]], fn {a, b} -> (b == 1 && a < bb_pos[:col]) end), fn {a, _b} -> a end ) )/2 # max( all cols where col < bb_pos[:col] and cell == 1   )/2
      :right ->
        Enum.min( Enum.map( Enum.filter( board[bb_pos[:row]], fn {a, b} -> (b == 1 && a > bb_pos[:col]) end), fn {a, _b} -> a end ) )/2 - 1 # max( all cols where col < bb_pos[:col] and cell == 1   )/2
      _ ->
        0
    end
  end

  # TODO:
  #@doc "Given a robot position and direction, return a list of indices of any robots that the active robot will hit."
  defp get_robot_blocked_indices(_robot_pos, _direction, _robots) do
    []
  end


  # TODO...
  def check_solution(_board, solution) do
    GenServer.cast(__MODULE__, {:check_solution, solution})
  end

  # TODO...
  @impl true
  def handle_cast({:check_solution, _solution}, state) do
    # Solve it and broadcast results to sockets.
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_game}, state) do
    {visual_board, boundary_board, goals} = populate_board()
    robots = populate_robots()

    {:noreply,
     %{
       state
       | boundary_board: boundary_board,
         visual_board: visual_board,
         goals: goals,
         robots: robots
     }}
  end

  @doc ""
  @impl true
  def handle_cast({:solution_found, registry_key, num_robots, num_moves, uid}, state) do
    Room.system_chat(
      registry_key,
      "A #{num_robots}-robot, #{num_moves}-move solution has been found."
    )

    response =
      Poison.encode!(%{
        content: %{ timer: state.current_timer, countdown: state.current_countdown},
        action: "switch_to_countdown"
      })

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    setting_countdown = state.setting_countdown

    {:noreply,
     %{
       state
       | solution_found: true,
         solution_moves: num_moves,
         solution_robots: num_robots,
         solution_uid: uid,
         current_countdown: setting_countdown
     }}
  end

  @doc "Determine the current clock mode, and send out a signal for clients to sync"
  @impl true
  def handle_cast({:broadcast_clock, registry_key}, state) do

    response = if (state.solution_found) do
        Poison.encode!(%{
          content: %{ timer: state.current_timer, countdown: state.current_countdown},
          action: "switch_to_countdown"
        })
    else
        Poison.encode!(%{
          content: %{timer: state.current_timer, countdown: state.setting_countdown},
          action: "switch_to_timer"
        })
    end

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
  end

  @doc ""
  @impl true
  def handle_cast({:award_points, registry_key, _num_robots, _num_moves, _uid}, state) do
    # ADD 1 PT TO WINNER, IFF SOLUTION WAS GOOD ENOUGH

    #   Room.system_chat(registry_key, "User has won with a #{robots}-robot, #{moves}-move solution.")
    response =
      Poison.encode!(%{
        content: %{timer: state.current_timer, countdown: state.setting_countdown},
        action: "switch_to_timer"
      })

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    reset_countdown = state.setting_countdown

    {:noreply,
     %{
       state
       | solution_found: false,
         solution_moves: 0,
         solution_robots: 0,
         solution_uid: 0,
         current_countdown: reset_countdown,
         current_timer: 0
     }}
  end

  @impl true
  def handle_cast({:broadcast_visual_board, registry_key}, state) do
    response = Poison.encode!(%{content: state.visual_board, action: "update_board"})

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast_robots, registry_key}, state) do
    response = Poison.encode!(%{content: state.robots, action: "update_robots"})

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast_goals, registry_key}, state) do
    response = Poison.encode!(%{content: state.goals, action: "update_goals"})

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
  end


  @doc "Tick 1 second"
  @impl GenServer
  def handle_info(:timerevent, state) do
    new_countdown =
      if state.solution_found do
        state.current_countdown - 1
      else
        state.current_countdown
      end

    new_timer = state.current_timer + 1

    # if state.current_countdown <= 0...

    {:noreply, %{state | current_countdown: new_countdown, current_timer: new_timer}}
  end

  # TODO: use these or get rid of them? When is a type better than a defstruct?
  @typedoc "User: { username: String, color: String, score: integer }"
  @type user_t :: %{
          username: String.t(),
          color: String.t(),
          score: integer,
          datestr: DateTime.t()
        }

  @typedoc "Position: { row: Integer, col: Integer }"
  @type position_t :: {integer, integer}

  @typedoc "Position2: { row: Integer, col: Integer }"
  @type position2_t :: %{x: integer, y: integer}

  @typedoc "Robot: { pos: position, color: String }"
  @type robot_t :: %{pos: position2_t, color: String.t(), moves: [String.t()]}

  @typedoc "Goal: { pos: position, symbol: String, active: boolean }"
  @type goal_t :: %{pos: position2_t, symbol: String.t(), active: boolean}

  @doc "Return 5 robots in unique, random positions, avoiding the center 4 squares."
  @spec populate_robots() :: [robot_t]
  def populate_robots() do
    robots = add_robot("red", [])
    robots = add_robot("green", robots)
    robots = add_robot("blue", robots)
    robots = add_robot("yellow", robots)
    add_robot("silver", robots)
  end

  # Given color, list of previous robots, add a single 'color' robot to an unoccupied square
  @spec add_robot(String.t(), [robot_t]) :: [robot_t]
  defp add_robot(color, robots) do
    open_squares = [0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15]
    rlist = rand_unique_pairs(open_squares, open_squares, robots)
    [%{pos: List.first(rlist), color: color, moves: ["up", "left", "down", "right"]} | robots]
  end

  @doc "Return a randomized boundary board, its visual map, and corresponding goal positions."
  @spec populate_board() :: {map, map, [goal_t]}
  def populate_board() do
    goal_symbols =
      Enum.shuffle([
        "RedMoon",
        "GreenMoon",
        "BlueMoon",
        "YellowMoon",
        "RedPlanet",
        "GreenPlanet",
        "BluePlanet",
        "YellowPlanet",
        "GreenCross",
        "RedCross",
        "BlueCross",
        "YellowCross",
        "RedGear",
        "GreenGear",
        "BlueGear",
        "YellowGear"
      ])

    goal_active =
      Enum.shuffle([
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false
      ])

    solid = for c <- 0..32, into: %{}, do: {c, 1}
    open = for c <- 1..31, into: %{0 => 1, 32 => 1}, do: {c, 0}
    a = for r <- 1..31, into: %{0 => solid, 32 => solid}, do: {r, open}

    a = put_in(a[14][14], 1)
    a = put_in(a[14][15], 1)
    a = put_in(a[14][16], 1)
    a = put_in(a[14][17], 1)
    a = put_in(a[14][18], 1)
    a = put_in(a[15][14], 1)
    a = put_in(a[16][14], 1)
    a = put_in(a[17][14], 1)
    a = put_in(a[18][14], 1)
    a = put_in(a[18][15], 1)
    a = put_in(a[18][16], 1)
    a = put_in(a[18][17], 1)
    a = put_in(a[14][18], 1)
    a = put_in(a[15][18], 1)
    a = put_in(a[16][18], 1)
    a = put_in(a[17][18], 1)
    a = put_in(a[18][18], 1)

    # two | per board edge, with certain spaces avoided
    v1 = Enum.random([4, 6, 8, 10, 12, 14])
    a = put_in(a[1][v1], 1)
    v2 = Enum.random([18, 20, 22, 24, 26, 28])
    a = put_in(a[1][v2], 1)
    v3 = Enum.random([4, 6, 8, 10, 12, 14])
    a = put_in(a[31][v3], 1)
    v4 = Enum.random([18, 20, 22, 24, 26, 28])
    a = put_in(a[31][v4], 1)
    v5 = Enum.random([4, 6, 8, 10, 12, 14])
    a = put_in(a[v5][1], 1)
    v6 = Enum.random([18, 20, 22, 24, 26, 28])
    a = put_in(a[v6][1], 1)
    v7 = Enum.random([4, 6, 8, 10, 12, 14])
    a = put_in(a[v7][31], 1)
    v8 = Enum.random([18, 20, 22, 24, 26, 28])
    a = put_in(a[v8][31], 1)

    # four "L"s per quadrant
    # rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [2, 4, 6, 8, 10, 12], [ {v1, 0}, {v2, 0}, {v3, 32}, {v4, 32}, {0, v5}, {0, v6}, {32, v7}, {32, v8} ])
    rlist =
      rand_distant_pairs([4, 6, 8, 10, 12, 14], [2, 4, 6, 8, 10, 12], [
        {0, v1},
        {0, v2},
        {32, v3},
        {32, v4},
        {v5, 0},
        {v6, 0},
        {v7, 32},
        {v8, 32}
      ])

    {a, goals} =
      add_L1(a, List.first(rlist), Enum.fetch!(goal_symbols, 0), Enum.fetch!(goal_active, 0), [])

    rlist = rand_distant_pairs([2, 4, 6, 8, 10, 12], [2, 4, 6, 8, 10, 12], rlist)

    {a, goals} =
      add_L2(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 1),
        Enum.fetch!(goal_active, 1),
        goals
      )

    rlist = rand_distant_pairs([2, 4, 6, 8, 10, 12], [4, 6, 8, 10, 12, 14], rlist)

    {a, goals} =
      add_L3(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 2),
        Enum.fetch!(goal_active, 2),
        goals
      )

    rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [4, 6, 8, 10, 12, 14], rlist)

    {a, goals} =
      add_L4(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 3),
        Enum.fetch!(goal_active, 3),
        goals
      )

    ############################################
    rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [18, 20, 22, 24, 26, 28], rlist)

    {a, goals} =
      add_L1(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 4),
        Enum.fetch!(goal_active, 4),
        goals
      )

    rlist = rand_distant_pairs([2, 4, 6, 8, 10, 12], [18, 20, 22, 24, 26, 28], rlist)

    {a, goals} =
      add_L2(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 5),
        Enum.fetch!(goal_active, 5),
        goals
      )

    rlist = rand_distant_pairs([2, 4, 6, 8, 10, 12], [20, 22, 24, 26, 28, 30], rlist)

    {a, goals} =
      add_L3(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 6),
        Enum.fetch!(goal_active, 6),
        goals
      )

    rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [20, 22, 24, 26, 28, 30], rlist)

    {a, goals} =
      add_L4(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 7),
        Enum.fetch!(goal_active, 7),
        goals
      )

    ############################################
    rlist = rand_distant_pairs([20, 22, 24, 26, 28, 30], [2, 4, 6, 8, 10, 12], rlist)

    {a, goals} =
      add_L1(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 8),
        Enum.fetch!(goal_active, 8),
        goals
      )

    rlist = rand_distant_pairs([18, 20, 22, 24, 26, 28], [2, 4, 6, 8, 10, 12], rlist)

    {a, goals} =
      add_L2(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 9),
        Enum.fetch!(goal_active, 9),
        goals
      )

    rlist = rand_distant_pairs([18, 20, 22, 24, 26, 28], [4, 6, 8, 10, 12, 14], rlist)

    {a, goals} =
      add_L3(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 10),
        Enum.fetch!(goal_active, 10),
        goals
      )

    rlist = rand_distant_pairs([20, 22, 24, 26, 28, 30], [4, 6, 8, 10, 12, 14], rlist)

    {a, goals} =
      add_L4(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 11),
        Enum.fetch!(goal_active, 11),
        goals
      )

    ############################################
    rlist = rand_distant_pairs([20, 22, 24, 26, 28, 30], [18, 20, 22, 24, 26, 28], rlist)

    {a, goals} =
      add_L1(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 12),
        Enum.fetch!(goal_active, 12),
        goals
      )

    rlist = rand_distant_pairs([18, 20, 22, 24, 26, 28], [18, 20, 22, 24, 26, 28], rlist)

    {a, goals} =
      add_L2(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 13),
        Enum.fetch!(goal_active, 13),
        goals
      )

    rlist = rand_distant_pairs([18, 20, 22, 24, 26, 28], [20, 22, 24, 26, 28, 30], rlist)

    {a, goals} =
      add_L3(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 14),
        Enum.fetch!(goal_active, 14),
        goals
      )

    rlist = rand_distant_pairs([20, 22, 24, 26, 28, 30], [20, 22, 24, 26, 28, 30], rlist)

    {a, goals} =
      add_L4(
        a,
        List.first(rlist),
        Enum.fetch!(goal_symbols, 15),
        Enum.fetch!(goal_active, 15),
        goals
      )

    ############################################

    # visual_map init:
    empty = for c <- 0..15, into: %{}, do: {c, 0}
    b = for r <- 0..15, into: %{}, do: {r, empty}
    b = populate_rows(a, b, 15)

    # put in final special blocks into center 4 squares
    b = put_in(b[7][7], 256)
    b = put_in(b[7][8], 257)
    b = put_in(b[8][7], 258)
    b = put_in(b[8][8], 259)

    visual_board = for {_k, v} <- b, do: for({_kk, vv} <- v, do: vv)
    {visual_board, a, goals}
  end

  # Add L
  @spec add_L1(map, {integer, integer}, String.t(), boolean, [goal_t]) :: {map, [goal_t]}
  defp add_L1(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in(a[row][col], 1)
    a = put_in(a[row][col + 1], 1)
    a = put_in(a[row - 1][col], 1)

    {a,
     [
       %{pos: %{y: div(row - 1, 2), x: div(col + 1, 2)}, symbol: goal_string, active: goal_active}
       | goals
     ]}
  end

  # Add L, rotated 90 deg CW
  @spec add_L2(map, {integer, integer}, String.t(), boolean, [goal_t]) :: {map, [goal_t]}
  defp add_L2(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in(a[row][col], 1)
    a = put_in(a[row][col + 1], 1)
    a = put_in(a[row + 1][col], 1)

    {a,
     [
       %{pos: %{y: div(row + 1, 2), x: div(col + 1, 2)}, symbol: goal_string, active: goal_active}
       | goals
     ]}
  end

  # Add L, rotated 180 deg
  @spec add_L3(map, {integer, integer}, String.t(), boolean, [goal_t]) :: {map, [goal_t]}
  defp add_L3(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in(a[row][col], 1)
    a = put_in(a[row][col - 1], 1)
    a = put_in(a[row + 1][col], 1)

    {a,
     [
       %{pos: %{y: div(row + 1, 2), x: div(col - 1, 2)}, symbol: goal_string, active: goal_active}
       | goals
     ]}
  end

  # Add L, rotated 270 deg CW
  @spec add_L4(map, {integer, integer}, String.t(), boolean, [goal_t]) :: {map, [goal_t]}
  defp add_L4(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in(a[row][col], 1)
    a = put_in(a[row][col - 1], 1)
    a = put_in(a[row - 1][col], 1)

    {a,
     [
       %{pos: %{y: div(row - 1, 2), x: div(col - 1, 2)}, symbol: goal_string, active: goal_active}
       | goals
     ]}
  end

  # Populate a row of visual_board (b) based on boundary board (a)
  # TODO: how do Elixir people usually write this + the next function?
  defp populate_rows(a, b, row) when row <= 0 do
    populate_cols(a, b, row, 15)
  end

  defp populate_rows(a, b, row) do
    b = populate_cols(a, b, row, 15)
    populate_rows(a, b, row - 1)
  end

  # TOP = 1    RIG = 2    BOT = 4    LEF = 8
  # TRT = 16   BRT = 32   BLT = 64   TLT = 128
  # Find the bordering cells of b[row][col] in the boundary_board (a) and stuff in the correct integer representation for frontend presentation
  defp populate_cols(a, b, row, col) when col <= 0 do
    cc = 2 * col + 1
    rr = 2 * row + 1

    put_in(
      b[row][col],
      a[rr - 1][cc] * 1 ||| a[rr][cc + 1] * 2 ||| a[rr + 1][cc] * 4 ||| a[rr][cc - 1] * 8 |||
        a[rr - 1][cc + 1] * 16 ||| a[rr + 1][cc + 1] * 32 ||| a[rr + 1][cc - 1] * 64 |||
        a[rr - 1][cc - 1] * 128
    )
  end

  defp populate_cols(a, b, row, col) do
    cc = 2 * col + 1
    rr = 2 * row + 1

    b =
      put_in(
        b[row][col],
        a[rr - 1][cc] * 1 ||| a[rr][cc + 1] * 2 ||| a[rr + 1][cc] * 4 ||| a[rr][cc - 1] * 8 |||
          a[rr - 1][cc + 1] * 16 ||| a[rr + 1][cc + 1] * 32 ||| a[rr + 1][cc - 1] * 64 |||
          a[rr - 1][cc - 1] * 128
      )

    populate_cols(a, b, row, col - 1)
  end

  # TODO: write this with position_t type
  @doc "Given a list of {int, int} pairs not to repeat, and two arrays to choose new tuples from, return a list with a new unique tuple"
  @spec rand_unique_pairs([integer], [integer], [%{x: integer, y: integer}]) :: [
          %{x: integer, y: integer}
        ]
  def rand_unique_pairs(rs, cs, avoids, cnt \\ 0) do
    rand_pair = %{x: Enum.random(cs), y: Enum.random(rs)}

    if cnt > 50 do
      [{-1, -1} | avoids]
    else
      if rand_pair in avoids do
        rand_unique_pairs(rs, cs, avoids, cnt + 1)
      else
        [rand_pair | avoids]
      end
    end
  end

  # TODO: write this with position_t type
  @doc "Given a list of {int, int} pairs to avoid, and two arrays to choose new tuples from, return a list with a new tuple at least 2 distance away"
  @spec rand_distant_pairs([integer], [integer], [{integer, integer}]) :: [{integer, integer}]
  def rand_distant_pairs(rs, cs, avoids, cnt \\ 0) do
    {r, c} = {Enum.random(rs), Enum.random(cs)}

    if cnt > 50 do
      [{-1, -1} | avoids]
    else
      if Enum.any?(avoids, fn {r1, c1} -> dist_under_2?({r1, c1}, {r, c}) end) do
        rand_distant_pairs(rs, cs, avoids, cnt + 1)
      else
        [{r, c} | avoids]
      end
    end
  end

  # TODO: write this with position_t type
  @doc "Take {x1, y1} and {x2, y2}; is the distance between them more than 2.0 (on condensed board; 4.0 on boundary_board)?"
  @spec dist_under_2?({integer, integer}, {integer, integer}) :: boolean
  def dist_under_2?({x1, y1}, {x2, y2}) do
    (y1 - y2) * (y1 - y2) + (x1 - x2) * (x1 - x2) <= 16.0
  end
end

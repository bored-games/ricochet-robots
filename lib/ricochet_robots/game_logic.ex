defmodule RicochetRobots.GameLogic do
  @moduledoc """
  This module contains functions that handle game logic.
  """

  import Bitwise

  alias RicochetRobots.{Game}

  @doc """
  Return whether the robot that matches the goal color is at the active goal.
  """
  @spec check_solution([Game.robot_t()], [Game.goal_t()]) :: boolean()
  def check_solution(robots, goals) do
    %{symbol: active_symbol, pos: active_pos} = Enum.find(goals, fn %{active: a} -> a end)

    active_color = active_symbol |> color_to_symbol()

    Enum.any?(robots, fn %{color: c, pos: p} ->
      c == active_color && p == active_pos
    end)
  end

  @doc """
  Given a list of moves and the state of the robots, simulate the moves taken
  by the robots.
  """
  def make_move(robots, board, []) do
    Enum.map(robots, fn robot -> calculate_moves(robot, robots, board) end)
  end

  def make_move(robots, board, [move | tailmoves]) do
    robots
    |> Enum.map(fn robot ->
      if robot.color == move.color do
        %{robot | pos: calculate_new_pos(robot.pos, move.direction, robots, board)}
      else
        robot
      end
    end)
    |> make_move(board, tailmoves)
  end

  defp calculate_new_pos(pos, direction, robots, board) do
    dir = String.to_atom(direction)

    new_coord =
      [get_wall_blocked_indices(pos, dir, board) | get_robot_blocked_indices(pos, dir, robots)]
      |> Enum.max()
      |> round()

    cond do
      dir == :up || dir == :down -> %{pos | y: new_coord}
      dir == :left || dir == :right -> %{pos | x: new_coord}
      true -> pos
    end
  end

  # Given a specific robot, a list of robots and a boundary_board, find the set
  # of legal moves for each robot.
  #
  # Note: Our walls are in a 33x33 array, while our robots are in a 16x16
  # array. We thus have to multiply by 2 to get the index of the walls.
  defp calculate_moves(robot, robots, board) do
    %{x: robot_x, y: robot_y} = robot.pos
    %{x: board_x, y: board_y} = %{y: 2 * robot_y + 1, x: round(2 * robot_x + 1)}
    robot_positions = Enum.map(robots, fn %{pos: p} -> p end)

    moves =
      [
        {%{x: robot_x - 1, y: robot_y}, board[board_y][board_x - 1], "left"},
        {%{x: robot_x + 1, y: robot_y}, board[board_y][board_x + 1], "right"},
        {%{x: robot_x, y: robot_y - 1}, board[board_y - 1][board_x], "up"},
        {%{x: robot_x, y: robot_y + 1}, board[board_y + 1][board_x], "down"}
      ]
      |> Enum.filter(fn {pos, wall, _dir} ->
        Enum.member?(robot_positions, pos) && wall == 1
      end)
      |> Enum.map(fn {_pos, _wall, dir} -> dir end)

    %{robot | moves: moves}
  end

  # Given a robot position and direction, return the relevant index of the
  # first wall the robot will hit.
  defp get_wall_blocked_indices(vb_pos, direction, board) do
    bb_pos = %{row: round(2 * vb_pos[:y] + 1), col: round(2 * vb_pos[:x] + 1)}

    case direction do
      :up ->
        # max( all cols where col < bb_pos[:col] and cell == 1   )/2
        for(z <- 0..32, into: [], do: {z, board[z][bb_pos[:col]]})
        |> Enum.filter(fn {a, b} -> b == 1 && a < bb_pos[:row] end)
        |> Enum.map(fn {a, _b} -> a end)
        |> Enum.max()
        |> (&(&1 / 2)).()

      :down ->
        # min( all rows where row > bb_pos[:row] and cell == 1   )/2-1
        for(z <- 0..32, into: [], do: {z, board[z][bb_pos[:col]]})
        |> Enum.filter(fn {a, b} -> b == 1 && a < bb_pos[:row] end)
        |> Enum.map(fn {a, _b} -> a end)
        |> Enum.min()
        |> (&(&1 / 2 - 1)).()

      :left ->
        # max( all cols where col < bb_pos[:col] and cell == 1   )/2
        board[bb_pos[:row]]
        |> Enum.filter(fn {a, b} -> b == 1 && a < bb_pos[:col] end)
        |> Enum.map(fn {a, _b} -> a end)
        |> Enum.max()
        |> (&(&1 / 2)).()

      :right ->
        # max( all cols where col < bb_pos[:col] and cell == 1   )/2
        board[bb_pos[:row]]
        |> Enum.filter(fn {a, b} -> b == 1 && a < bb_pos[:col] end)
        |> Enum.map(fn {a, _b} -> a end)
        |> Enum.min()
        |> (&(&1 / 2 - 1)).()

      _ ->
        0
    end
  end

  # Given a robot position and direction, return a list of indices of any robots
  # that the active robot will hit.
  defp get_robot_blocked_indices(robot_pos, direction, robots) do
    %{x: rx, y: ry} = robot_pos

    case direction do
      :up ->
        robots
        |> Enum.filter(fn %{pos: %{x: xx, y: yy}} -> xx == rx && yy < ry end)
        |> Enum.map(fn %{pos: %{y: yy}} -> yy + 1 end)

      :down ->
        robots
        |> Enum.filter(fn %{pos: %{x: xx, y: yy}} -> xx == rx && yy > ry end)
        |> Enum.map(fn %{pos: %{y: yy}} -> yy - 1 end)

      :left ->
        robots
        |> Enum.filter(fn %{pos: %{x: xx, y: yy}} -> xx < rx && yy == ry end)
        |> Enum.map(fn %{pos: %{x: xx}} -> xx + 1 end)

      :right ->
        robots
        |> Enum.filter(fn %{pos: %{x: xx, y: yy}} -> xx > rx && yy == ry end)
        |> Enum.map(fn %{pos: %{x: xx}} -> xx - 1 end)
    end
  end

  @doc "Return 5 robots in unique, random positions, avoiding the center 4 squares."
  @spec populate_robots() :: [Game.robot_t()]
  def populate_robots() do
    []
    |> add_robot("red")
    |> add_robot("green")
    |> add_robot("blue")
    |> add_robot("yellow")
    |> add_robot("silver")
  end

  # Given color, list of previous robots, add a single 'color' robot to an unoccupied square
  @spec add_robot([Game.robot_t()], String.t()) :: [Game.robot_t()]
  defp add_robot(robots, color) do
    robot = %{pos: rand_position(robots), color: color, moves: ["up", "left", "down", "right"]}
    [robot | robots]
  end

  @open_indices Enum.to_list(0..15) -- [7, 8]

  # Given a list of occupied positions, choose a new position.
  @spec rand_position([Game.position_t()]) :: [Game.position_t()]
  defp rand_position(robots) do
    occupied = for(robot <- robots, do: robot.pos) |> Enum.to_list()

    for(x <- @open_indices, y <- @open_indices, do: %{x: x, y: y})
    |> Enum.to_list()
    |> (&(&1 -- occupied)).()
    |> Enum.random()
  end

  @doc """
  Return a randomized boundary board, its visual map, and corresponding goal positions.
  """
  @spec populate_board() :: {map, map, [Game.goal_t()]}
  def populate_board() do
    goal_symbols = Game.goal_symbols() |> Enum.shuffle()

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

    a =
      for i <- [14, 18], j <- 14..18 do
        put_in(a[i][j], 1) |> put_in(a[j][i], 1)
      end

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
    # rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [2, 4, 6, 8, 10, 12], [
    # {v1, 0}, {v2, 0}, {v3, 32}, {v4, 32}, {0, v5}, {0, v6}, {32, v7}, {32,
    # v8} ])
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
  @spec add_L1(map, {integer, integer}, String.t(), boolean, [Game.goal_t()]) ::
          {map, [Game.goal_t()]}
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
  @spec add_L2(map, {integer, integer}, String.t(), boolean, [Game.goal_t()]) ::
          {map, [Game.goal_t()]}
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
  @spec add_L3(map, {integer, integer}, String.t(), boolean, [Game.goal_t()]) ::
          {map, [Game.goal_t()]}
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
  @spec add_L4(map, {integer, integer}, String.t(), boolean, [Game.goal_t()]) ::
          {map, [Game.goal_t()]}
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
  # Find the bordering cells of b[row][col] in the boundary_board (a) and stuff
  # in the correct integer representation for frontend presentation
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
  @doc """
  Take {x1, y1} and {x2, y2}; is the distance between them more than 2.0on
  "visual board" (4.0 on "boundary board")?
  """
  @spec dist_under_2?({integer, integer}, {integer, integer}) :: boolean
  def dist_under_2?({x1, y1}, {x2, y2}) do
    (y1 - y2) * (y1 - y2) + (x1 - x2) * (x1 - x2) <= 16.0
  end

  @red_symbols MapSet.new(["RedMoon", "RedPlanet", "RedCross", "RedGear"])
  @green_symbols MapSet.new(["GreenMoon", "GreenPlanet", "GreenCross", "GreenGear"])
  @blue_symbols MapSet.new(["BlueMoon", "BluePlanet", "BlueCross", "BlueGear"])
  @yellow_symbols MapSet.new(["YellowMoon", "YellowPlanet", "YellowCross", "YellowGear"])

  defp color_to_symbol(color) do
    cond do
      MapSet.member?(@red_symbols, color) -> "red"
      MapSet.member?(@green_symbols, color) -> "green"
      MapSet.member?(@blue_symbols, color) -> "blue"
      MapSet.member?(@yellow_symbols, color) -> "yellow"
    end
  end
end

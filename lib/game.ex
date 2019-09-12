defmodule RicochetRobots.Game do
  import Bitwise
  use GenServer

  ### TODO: Move these into seperate modules and make them all structs?
  ### I don't know how to compile/link in that case :-(

  @typedoc "User: { username: String, color: String, score: integer }"
  @type user_t :: %{
          username: String.t(),
          color: String.t(),
          score: integer,
          datestr: DateTime.t()
        }

  @typedoc "Position: { row: Integer, col: Integer }"
  @type position_t :: {integer, integer}

  @typedoc "Robot: { pos: position, color: String }"
  @type robot_t :: %{pos: position_t, color: String.t()}

  @typedoc "Goal: { pos: position, name: String, active: boolean }"
  @type goal_t :: %{pos: position_t, name: String.t(), active: boolean}

  defstruct visual_board: nil,
            boundary_board: nil,
            robots: [],
            goals: [],
            users: [],
            clock: 0,
            countdown: 60,
            title: "GOATS",
            idk_help: nil

  @impl true
  def init(_) do
    {visual_board, boundary_board, goals} = build_board()

    {:ok,
     %{
       visual_board: visual_board,
       boundary_board: boundary_board,
       robots: get_robots(),
       goals: goals,
       users: [new_user([])],
       clock: 0,
       countdown: 0,
       title: "GOAT"
     }}
  end

  @impl GenServer
  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end

  @impl GenServer
  def handle_call({cmd, content}, _, state) do
    case cmd do
      # Tick?
      001 ->
        {:reply, Map.get(state, content), state}

      # update board layout
      100 ->
        {:reply, Map.get(state, content), state}

      # update robots positions
      101 ->
        {:reply, Map.get(state, content), state}

      # update goalList (positions & active goal)
      102 ->
        {:reply, Map.get(state, content), state}

      # update new Goal?
      103 ->
        {:reply, Map.get(state, content), state}

      # switch to countdown (solution found)
      104 ->
        {:reply, Map.get(state, content), state}

      # switch to clock?
      105 ->
        {:reply, Map.get(state, content), state}

      # update users
      200 ->
        {:reply, Map.get(state, content), state}

      # update user
      201 ->
        {:reply, Map.get(state, content), state}

      # update chat
      202 ->
        {:reply, Map.get(state, content), state}

      _ ->
        {:stop, :unknown_cmd, state}
    end
  end

  @impl GenServer
  def handle_info(:timerevent, state) do
    IO.puts("received :timerevent...")
    {:noreply, state}
  end

  @doc "Return 5 robots in unique, random positions, avoiding the center 4 squares."
  @spec get_robots() :: [robot_t]
  def get_robots() do
    robots = add_robot("red", [])
    robots = add_robot("green", robots)
    robots = add_robot("blue", robots)
    robots = add_robot("yellow", robots)
    add_robot("silver", robots)
  end

  @spec add_robot(String.t(), [robot_t]) :: [robot_t]
  defp add_robot(color, robots) do
    open_squares = [0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15]
    rlist = rand_unique_pairs(open_squares, open_squares, robots)
    [%{pos: List.first(rlist), color: color} | robots]
  end

  @doc "Return a randomized board, it's visual map, and corresponding goal positions."
  @spec build_board() :: {map, map, [goal_t]}
  def build_board() do
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

    goal_active = Enum.shuffle([true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false])

    a = %{
      0 => %{ 0 => 1, 1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1, 6 => 1, 7 => 1, 8 => 1, 9 => 1, 10 => 1, 11 => 1, 12 => 1, 13 => 1, 14 => 1, 15 => 1, 16 => 1, 17 => 1, 18 => 1, 19 => 1, 20 => 1, 21 => 1, 22 => 1, 23 => 1, 24 => 1, 25 => 1, 26 => 1, 27 => 1, 28 => 1, 29 => 1, 30 => 1, 31 => 1, 32 => 1
      },
      1 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      2 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      3 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      4 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      5 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      6 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      7 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      8 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      9 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      10 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      11 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      12 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      13 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      14 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 1, 15 => 1, 16 => 1, 17 => 1, 18 => 1, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      15 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 1, 15 => 1, 16 => 1, 17 => 1, 18 => 1, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      16 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 1, 15 => 1, 16 => 1, 17 => 1, 18 => 1, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      17 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 1, 15 => 1, 16 => 1, 17 => 1, 18 => 1, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      18 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 1, 15 => 1, 16 => 1, 17 => 1, 18 => 1, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      19 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      20 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      21 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      22 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      23 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      24 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      25 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      26 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      27 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      28 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      29 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      30 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      31 => %{ 0 => 1, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0, 9 => 0, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0, 17 => 0, 18 => 0, 19 => 0, 20 => 0, 21 => 0, 22 => 0, 23 => 0, 24 => 0, 25 => 0, 26 => 0, 27 => 0, 28 => 0, 29 => 0, 30 => 0, 31 => 0, 32 => 1
      },
      32 => %{ 0 => 1, 1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1, 6 => 1, 7 => 1, 8 => 1, 9 => 1, 10 => 1, 11 => 1, 12 => 1, 13 => 1, 14 => 1, 15 => 1, 16 => 1, 17 => 1, 18 => 1, 19 => 1, 20 => 1, 21 => 1, 22 => 1, 23 => 1, 24 => 1, 25 => 1, 26 => 1, 27 => 1, 28 => 1, 29 => 1, 30 => 1, 31 => 1, 32 => 1
      }
    }

    # two | per board edge, with certain spaces avoided
    a = put_in(a[1][Enum.random([4, 6, 8, 10, 12, 14])], 1)
    a = put_in(a[1][Enum.random([18, 20, 22, 24, 26, 28])], 1)
    a = put_in(a[31][Enum.random([4, 6, 8, 10, 12, 14])], 1)
    a = put_in(a[31][Enum.random([18, 20, 22, 24, 26, 28])], 1)
    a = put_in(a[Enum.random([4, 6, 8, 10, 12, 14])][1], 1)
    a = put_in(a[Enum.random([18, 20, 22, 24, 26, 28])][1], 1)
    a = put_in(a[Enum.random([4, 6, 8, 10, 12, 14])][31], 1)
    a = put_in(a[Enum.random([18, 20, 22, 24, 26, 28])][31], 1)

    # four "L"s per quadrant
    rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [2, 4, 6, 8, 10, 12], [])

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

    b = %{
      0 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      1 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      2 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      3 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      4 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      5 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      6 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      7 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      8 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      9 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      10 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      11 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      12 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      13 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      14 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      },
      15 => %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 0,
        10 => 0,
        11 => 0,
        12 => 0,
        13 => 0,
        14 => 0,
        15 => 0
      }
    }

    b = populate_rows(a, b, 15)

    # put in final special blocks into center 4 squares
    b = put_in(b[7][7], 256)
    b = put_in(b[7][8], 257)
    b = put_in(b[8][7], 258)
    b = put_in(b[8][8], 259)

    {b, a, goals}
  end

  @spec add_L1(map, {integer, integer}, String.t(), boolean, [goal_t]) :: {map, [goal_t]}
  defp add_L1(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in(a[row][col], 1)
    a = put_in(a[row][col + 1], 1)
    a = put_in(a[row - 1][col], 1)

    {a,
     [%{pos: {div(row, 2) - 1, div(col, 2) + 1}, name: goal_string, active: goal_active} | goals]}
  end

  @spec add_L2(map, {integer, integer}, String.t(), boolean, [goal_t]) :: {map, [goal_t]}
  defp add_L2(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in(a[row][col], 1)
    a = put_in(a[row][col + 1], 1)
    a = put_in(a[row + 1][col], 1)

    {a,
     [%{pos: {div(row, 2) - 1, div(col, 2) - 1}, name: goal_string, active: goal_active} | goals]}
  end

  @spec add_L3(map, {integer, integer}, String.t(), boolean, [goal_t]) :: {map, [goal_t]}
  defp add_L3(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in(a[row][col], 1)
    a = put_in(a[row][col - 1], 1)
    a = put_in(a[row + 1][col], 1)

    {a,
     [%{pos: {div(row, 2) + 1, div(col, 2) - 1}, name: goal_string, active: goal_active} | goals]}
  end

  @spec add_L4(map, {integer, integer}, String.t(), boolean, [goal_t]) :: {map, [goal_t]}
  defp add_L4(a, {row, col}, goal_string, goal_active, goals) do
    a = put_in(a[row][col], 1)
    a = put_in(a[row][col - 1], 1)
    a = put_in(a[row - 1][col], 1)

    {a,
     [%{pos: {div(row, 2) - 1, div(col, 2) - 1}, name: goal_string, active: goal_active} | goals]}
  end

  defp populate_rows(a, b, row) when row <= 0 do
    populate_cols(a, b, row, 15)
  end

  defp populate_rows(a, b, row) do
    b = populate_cols(a, b, row, 15)
    populate_rows(a, b, row - 1)
  end

  # TOP = 1
  # RIG = 2
  # BOT = 4
  # LEF = 8
  # TRT = 16
  # BRT = 32
  # BLT = 64
  # TLT = 128

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

  @doc "Return a new user with unique, randomized name"
  @spec new_user([user_t]) :: user_t
  def new_user(users) do
    arr1 = [
      "Robot",
      "Doctor",
      "Puzzle",
      "Automaton",
      "Data",
      "Buzz",
      "Infinity",
      "Cyborg",
      "Android",
      "Electro",
      "Robo",
      "Battery",
      "Beep"
    ]

    arr2 = [
      "Lover",
      "Love",
      "Power",
      "Clicker",
      "Friend",
      "Genius",
      "Beep",
      "Boop",
      "Sim",
      "Asimov",
      "Talos"
    ]

    arr3 = ["69", "420", "XxX", "2001", "", "", "", "", "", "", "", "", ""]
    username = Enum.random(arr1) <> Enum.random(arr2) <> Enum.random(arr3)

    # Better way to verify username is not in use?
    if Enum.member?(Enum.map(users, &Map.get(&1, :username)), username) do
      new_user(users)
    else
      {:ok, datestr} = DateTime.now("Etc/UTC")
      %{username: username, color: "#c6c6c6", score: 0, joined: datestr}
    end
  end

  @doc "Given a list of {int, int} pairs not to repeat, and two arrays to choose new tuples from, return a list with a new unique tuple"
  @spec rand_unique_pairs([integer], [integer], [{integer, integer}]) :: [{integer, integer}]
  def rand_unique_pairs(rs, cs, avoids, cnt \\ 0) do
    {r, c} = {Enum.random(rs), Enum.random(cs)}

    if cnt > 50 do
      [{-1, -1} | avoids]
    else
      if {r, c} in avoids do
        rand_unique_pairs(rs, cs, avoids, cnt + 1)
      else
        [{r, c} | avoids]
      end
    end
  end

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

  @doc "Take {x1, y1} and {x2, y2}; is the distance between them more than 2.0 (on condensed board; 4.0 on boundary_board)?"
  @spec dist_under_2?({integer, integer}, {integer, integer}) :: boolean
  def dist_under_2?({x1, y1}, {x2, y2}) do
    (y1 - y2) * (y1 - y2) + (x1 - x2) * (x1 - x2) <= 16.0
  end
end

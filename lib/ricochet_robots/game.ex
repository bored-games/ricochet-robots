defmodule RicochetRobots.Game do
  use GenServer
  import Bitwise
  require Logger

  defstruct boundary_board: nil,
            visual_board: nil,
            robots: [],
            goals: [],
            countdown: 60,
            timer: 0

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.debug("[Game: Started game]")
    { visual_board, boundary_board, goals } = populate_board()
    robots = populate_robots()
    state = %__MODULE__{boundary_board: boundary_board, visual_board: visual_board, goals: goals, robots: robots}

    {:ok, state}
  end

  def new_game(registry_key) do
    Logger.debug("[Game: New game]")
    GenServer.cast(__MODULE__, {:new_game})
    broadcast_visual_board(registry_key)
    broadcast_robots(registry_key)
    broadcast_goals(registry_key)
  end

  def broadcast_visual_board(registry_key) do
    GenServer.cast(__MODULE__, {:broadcast_visual_board, registry_key})
  end

  def broadcast_robots(registry_key) do
    GenServer.cast(__MODULE__, {:broadcast_robots, registry_key})
  end

  def broadcast_goals(registry_key) do
    GenServer.cast(__MODULE__, {:broadcast_goals, registry_key})
  end

  def get_board() do
    GenServer.call(__MODULE__, :get_visual_board)
  end

  def get_robots() do
    GenServer.call(__MODULE__, :get_robots)
  end

  def get_goals() do
    GenServer.call(__MODULE__, :get_goals)
  end

  # def create_board() do
  #   # Board elements: nil, :robot, :vertical_wall, :horizontal_wall ?

  #   board = %{}

  #   for x <- 0..32 do
  #     for y <- 0..32 do
  #       board = Map.put(board, {x, y}, nil)
  #     end
  #   end

  #   board
  # end

  # def populate_board(board) do
  #   # Randomly populate board with elements (represented as atoms?).
  #   board
  # end

  def check_solution(_board, solution) do
    GenServer.cast(__MODULE__, {:check_solution, solution})
  end


  @impl true
  def handle_cast({:check_solution, _solution}, state) do
    # Solve it and broadcast results to sockets.
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_game}, state) do
    { visual_board, boundary_board, goals } = populate_board()
    robots = populate_robots()
    {:noreply, %{state | boundary_board: boundary_board, visual_board: visual_board, goals: goals, robots: robots}}
  end


  @impl true
  def handle_cast({:broadcast_visual_board, registry_key}, state) do
    Logger.debug("[Broadcast board]")
    response = Poison.encode!( %{ content: state.visual_board, action: "update_board" }  )

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn(entries) ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
  end


  @impl true
  def handle_cast({:broadcast_robots, registry_key}, state) do
    Logger.debug("[Broadcast robots]")
    response = Poison.encode!( %{ content: state.robots, action: "update_robots" }  )

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn(entries) ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
  end


  @impl true
  def handle_cast({:broadcast_goals, registry_key}, state) do
    Logger.debug("[Broadcast goals]")
    response = Poison.encode!( %{ content: state.goals, action: "update_goals" }  )

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn(entries) ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
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
  @spec populate_robots() :: [ robot_t ]
  def populate_robots() do
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
  @spec populate_board() :: { map, map, [ goal_t ] }
  def populate_board() do
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
    v1 = Enum.random([4,6,8,10,12,14])
    a = put_in a[1][ v1 ], 1
    v2 = Enum.random([18,20,22,24,26,28])
    a = put_in a[1][ v2 ], 1
    v3 = Enum.random([4,6,8,10,12,14])
    a = put_in a[31][ v3 ], 1
    v4 = Enum.random([18,20,22,24,26,28])
    a = put_in a[31][ v4 ], 1
    v5 = Enum.random([4,6,8,10,12,14])
    a = put_in a[ v5 ][1], 1
    v6 = Enum.random([18,20,22,24,26,28])
    a = put_in a[ v6 ][1], 1
    v7 = Enum.random([4,6,8,10,12,14])
    a = put_in a[ v7 ][31], 1
    v8 = Enum.random([18,20,22,24,26,28])
    a = put_in a[ v8 ][31], 1

    # TODO: ensure L's aren't too close to |'s?
    # four "L"s per quadrant
    #rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [2, 4, 6, 8, 10, 12], [ {v1, 0}, {v2, 0}, {v3, 32}, {v4, 32}, {0, v5}, {0, v6}, {32, v7}, {32, v8} ])
    rlist = rand_distant_pairs([4, 6, 8, 10, 12, 14], [2, 4, 6, 8, 10, 12], [ {0, v1}, {0, v2}, {32, v3}, {32, v4}, {v5, 0}, {v6, 0}, {v7, 32}, {v8, 32} ])
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

    visual_board = for {_k, v} <- b, do: (for {_kk, vv} <- v, do: vv)
    { visual_board, a, goals }
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
    ((y1-y2)*(y1-y2) + (x1-x2)*(x1-x2)) <= 16.1 # HAHA I am using 16.1 not 16 because I like the resulting boards better.
  end




end

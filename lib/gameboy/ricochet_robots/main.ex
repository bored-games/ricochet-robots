defmodule Gameboy.RicochetRobots.Main do
  @moduledoc """
  Ricochet Robots game components, including settings, solving, game state, etc.

  Consider splitting new_game, new_board, and new_round.
  """

  use GenServer
  require Logger

  alias Gameboy.{Room, GameSupervisor}
  alias Gameboy.RicochetRobots.{GameLogic}

  defstruct room_name: nil,
            boundary_board: nil,
            visual_board: nil,
            robots: [],
            goals: [],
            # Time in seconds after a solution is found (60, 6 for testing)
            setting_countdown: 6,
            # 1-robot solutions below this value should not count
            setting_min_moves: 3,
            # new board generated ever `n` many puzzles
            setting_puzzles_before_new: 8,
            # new board generated after this many more puzzles
            current_puzzles_until_new: 8,
            # current countdown: at 0, best solution wins
            current_countdown: 6,
            # current timer
            current_timer: 0,
            # boolean: has solution been found
            solution_found: false,
            # number of moves in current best solution
            solution_moves: 0,
            # number of robots in current best solution
            solution_robots: 0,
            # user id of current best solution
            best_solution_player_name: nil,
            # storage for the solution robot positions
            best_solution_robots: [],
            # storage for the solution robot positions
            best_solution_moves: "",
            # store goal indices after they have been used...
            goal_history: [],
            solver_enabled: true

  @type t :: %{
          room_name: String.t(),
          boundary_board: map,
          visual_board: map,
          robots: [robot_t],
          goals: [goal_t],
          setting_countdown: integer,
          setting_min_moves: integer,
          setting_puzzles_before_new: integer,
          current_puzzles_until_new: integer,
          current_countdown: integer,
          current_timer: integer,
          solution_found: boolean,
          solution_moves: integer,
          solution_robots: integer,
          best_solution_player_name: String.t(),
          best_solution_robots: [robot_t],
          best_solution_moves: String.t(),
          goal_history: [integer],
          solver_enabled: boolean
        }

  @typedoc "Position: { row: Integer, col: Integer }"
  @type position_t :: %{x: integer, y: integer}

  @typedoc "Goal: { pos: position, symbol: String, active: boolean }"
  @type goal_t :: %{pos: position_t, symbol: String.t(), active: boolean}

  @typedoc "Move"
  @type move_t :: %{color: String.t(), direction: String.t()}

  @typedoc "Robot: { pos: position, color: String, moves: [move] }"
  @type robot_t :: %{pos: position_t, color: String.t(), moves: [move_t]}

  @typedoc "Erlang's queue for solver"
  @type queue() :: :queue.queue()


  @goal_symbols [
    "RedMoon",
    "GreenMoon",
    "BlueMoon",
    "YellowMoon",
    "RedPlanet",
    "GreenPlanet",
    "BluePlanet",
    "YellowPlanet",
    "RedCross",
    "GreenCross",
    "BlueCross",
    "YellowCross",
    "RedGear",
    "GreenGear",
    "BlueGear",
    "YellowGear"
  ]

  def goal_symbols(), do: @goal_symbols

  def start_link(%{room_name: room_name} = opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(room_name))
  end

  @impl true
  @spec init(%{room_name: pid()}) :: {:ok, %__MODULE__{}}
  def init(%{room_name: room_name} = _opts) do
    Logger.info("[#{room_name}: Ricochet Robots] New game initialized.")
    
    state = new_round(%__MODULE__{room_name: room_name})
    :timer.send_interval(1000, :timerevent)

    {:ok, state}
  end

  @doc """
  Begin a new game (new boards, new robot positions, new goal positions).

  Broadcast new game information and clear all move queues.
  """
  @spec new(room_name: String.t()) :: nil
  def new(room_name) do
    GameSupervisor.start_child(__MODULE__, %{room_name: room_name})
    # Room.system_chat(room_name, "A new game of Ricochet Robots is starting!")
  end


  def new_round(state) do
    
    puzzles_until_new = state.current_puzzles_until_new

    new_state =
      if puzzles_until_new < 1 or state.boundary_board == nil do
        {visual_board, boundary_board, goals} = GameLogic.populate_board()
        robots = GameLogic.populate_robots(boundary_board)
        %{ state
        | boundary_board: boundary_board,
          visual_board: visual_board,
          goals: goals,
          robots: robots,
          current_puzzles_until_new: state.setting_puzzles_before_new,
          current_countdown: state.setting_countdown,
          current_timer: 0,
          solution_found: false,
          solution_moves: 0,
          solution_robots: 0,
          best_solution_player_name: nil,
          best_solution_robots: [],
          best_solution_moves: "",
          goal_history: []
      }
      else
        goals = GameLogic.choose_new_goal(state.goals)
        %{ state
        | goals: goals,
          robots: state.best_solution_robots,
          current_puzzles_until_new: puzzles_until_new - 1,
          current_countdown: state.setting_countdown,
          current_timer: 0,
          solution_found: false,
          solution_moves: 0,
          solution_robots: 0,
          best_solution_player_name: nil,
          best_solution_robots: [],
          best_solution_moves: ""
        }
      end
    

    broadcast_visual_board(new_state)
    broadcast_robots(new_state)
    broadcast_goals(new_state)
    broadcast_clock(new_state)
    broadcast_clear_moves(new_state)

    if state.solver_enabled do
      Task.async(fn -> spawn_solver(new_state) end )
    end

    new_state
  end



  @doc """
  ...
  A graph contains %{num_moves, num_robots_moved => %MapSet{goal_robot_positions, [extra_robot_positions]}
  or maybe... {target_robot, other_robots} => [moved_robot_strings]

  """
  @spec spawn_solver(__MODULE__.t()) :: :ok
  def spawn_solver(state) do

   
    # Logger.info( "[Solver] #{inspect state.robots}." )
    case Enum.find(state.goals, fn %{active: a} -> a end) do
      %{symbol: active_symbol, pos: active_pos} -> 
        active_color = active_symbol |> GameLogic.color_to_symbol()
        
        {[target_robot_obj | _], extra_robots_obj} = Enum.split_with(state.robots, fn %{color: c} -> c == active_color end)

        goal = Enum.find(state.goals, fn %{active: a} -> a end)
        target_robot = {target_robot_obj.pos.x, target_robot_obj.pos.y}
        extra_robots = extra_robots_obj |> Enum.map(fn %{pos: p} -> {p.x, p.y} end)

        init_queue = :queue.new()
        init_queue = :queue.in({ target_robot, extra_robots, [] }, init_queue)
        empty_next_layer_queue = :queue.new()

        # compute the stopping points for each cell and direction.
        stopping_board = GameLogic.precompute_stopping_cells(state.boundary_board)

        Logger.info( "[Solver] initialized. Must get #{inspect target_robot} to #{inspect {goal.pos.x, goal.pos.y}}. Other robots are: #{inspect extra_robots}." )
       
        case bfs(init_queue, MapSet.new, [], empty_next_layer_queue, 0, {goal.pos.x, goal.pos.y}, stopping_board) do
          {:bfs_success, history} ->
            colormap = extra_robots_obj
                       |> Enum.map(fn %{color: c} -> c  end)
            history_str = history
                          |> Enum.reverse()
                          |> Enum.map(fn m ->
                            case m do
                              {id, d} -> {Enum.at(colormap, id), d}
                              d -> {target_robot_obj.color, d}
                            end
                          end)
            robots_moved = Enum.map(history_str, fn {c, _d} -> c end) |> Enum.uniq |> length
            Logger.info( "[Solver] Success! #{inspect length(history)} moves, #{inspect robots_moved} robots: #{inspect history_str}." )
            Room.system_chat(state.room_name, "Solver has completed.")

          status ->
            Logger.info("[Solver] has completed with status #{status}.")
        end


      _ -> :solver_err_no_goals

    end
  end
  
  # a node is {target_robot, [other_robots], [shortest-path-history]}
  

  # Queue is the current layer we are traversing. But a node here also keeps track of history-moves (shortest path to get here) and used-robots.
  # History is a mapset so that we don't repeat cycles(?). It does not need values, just unique board positions.
  # Next_Layer is the set of nodes in the next layer, confirmed not to be solutions already
  # Number_Moves just keeps track of the layer because it's easy.

  defp bfs([], _history, [], _, _goal, _stopping_board) do
    :bfs_failed
  end

  defp bfs(_neighbors, _history, _next_layer, 15, _goal, _stopping_board) do
    Logger.info( "[BFS] Max depth reached." )
    :bfs_max_depth_reached
  end


  # breadth-first search
  defp bfs(queue, discovered_nodes, history, next_layer, num_moves, goal, stopping_board) do
    
    case :queue.out(queue) do
      {:empty, {[], []}} ->
        # Logger.info( "[BFS] Entering depth #{num_moves + 1}." )
        empty_next_layer_queue = :queue.new()
        bfs(next_layer, discovered_nodes, history, empty_next_layer_queue, num_moves+1, goal, stopping_board)

      {{:value, {active_robot, extra_robots, history}}, qtail} ->

        # first test active_robot because if there is a solution, this will be the fastest way.
        new_nodes = [:up, :down, :left, :right] # to do , move this into move_target_robot
                    |> Enum.map(fn m ->
                      {GameLogic.solver_move_target_robot(active_robot, extra_robots, stopping_board, m, goal), [m | history] }
                    end)
        case Enum.find( new_nodes, nil, fn {{soln_found, _, _}, _} -> soln_found end) do
          {{_soln_found, _active_robot, _extra_robots}, history} -> 
            {:bfs_success, history}
          nil -> 
            # active robot has no solution so let's get add all the child nodes to those found by moving extra_robots.
            new_nodes = new_nodes |> Enum.map(fn {{_, ar, ers}, h} -> {ar, ers, h} end)
            
            more_new_nodes = GameLogic.solver_move_extra_robots(active_robot, extra_robots, stopping_board, history)
            all_new_nodes = new_nodes ++ more_new_nodes

            {discovered_nodes, next_queue} = Enum.reduce(all_new_nodes, {discovered_nodes, next_layer}, fn {ar, ers, h}, {discnodes, queue} ->
                sorted_ers = Enum.sort(ers)
                case MapSet.member?(discovered_nodes, {ar, sorted_ers}) do
                  false -> {MapSet.put(discnodes, {ar, sorted_ers}), :queue.in({ar, ers, h}, queue)}
                  _ -> {discnodes, queue}
                end
              end)
              
            bfs(qtail, discovered_nodes, history, next_queue, num_moves, goal, stopping_board)
        end

    end
  end

  @doc """
  Game functions that *have* to be sent out when a client joins, i.e. send out the board
  """
  @spec welcome_player(__MODULE__.t(), String.t()) :: :ok
  def welcome_player(state, _player_name) do
    broadcast_visual_board(state)
    broadcast_robots(state)
    broadcast_goals(state)
    broadcast_clock(state)
    :ok
  end

    
  def handle_game_action(action, content, socket_state) do
    case action do
      "submit_movelist" -> 
        new_robots = __MODULE__.move_robots(socket_state.room_name, socket_state.player_name, content)
        Poison.encode!(%{content: new_robots, action: "update_robots"})
      _ -> :error_unknown_game_action
    end
  end


  # FETCH GAME: it has been registered under the room_name of the room in which it was started.
  @spec fetch(String.t()) :: {:ok, __MODULE__.t()} | :error_finding_game | :error_returning_state
  def fetch(room_name) do
    case GenServer.whereis(via_tuple(room_name)) do
      nil -> :error_finding_game
      _proc -> 
        case GenServer.call(via_tuple(room_name), :get_state) do
          {:ok, game} -> {:ok, game}
          _ -> :error_returning_state
        end
      end
  end
  

  def broadcast_visual_board(state) do
    message = Poison.encode!(%{action: "update_board", content: state.visual_board})
    GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
  end

  def broadcast_robots(state) do
    message = Poison.encode!(%{action: "update_robots", content: state.robots})
    GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
  end

  def broadcast_goals(state) do
    message = Poison.encode!(%{action: "update_goals", content: state.goals})
    GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
  end

  def broadcast_clock(state) do
    message =
      Poison.encode!(%{
        action: if(state.solution_found, do: "switch_to_countdown", else: "switch_to_timer"),
        content: %{timer: state.current_timer, countdown: state.current_countdown}
      })
    GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
  end

  @doc """
  Send out command to clear queue of moves. At a new game, for example, all
  queued moves should be forced to clear.
  """
  def broadcast_clear_moves(state) do
    message = Poison.encode!(%{action: "clear_moves_queue", content: ""})
    GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
  end



  @impl true
  def handle_cast({:broadcast_to_players, message}, state) do
    Room.broadcast_to_players(message, state.room_name)
    {:noreply, state}
  end

  
  @doc """
  Accept a set of moves from the user. Get the next set of valid moves.

  Also check whether the submitted set of moves is a solution to the board. If it is a valid solution, update the round state accordingly.
  """
  @spec move_robots(String.t(), String.t(), [move_t]) :: [robot_t]
  def move_robots(room_name, player_name, moves) do
    {:ok, state} = fetch(room_name)

    {moved_robots, verbose_move_list} = GameLogic.make_move(state.robots, state.boundary_board, "", moves)
    if GameLogic.check_solution(moved_robots, state.goals) do
      state = GenServer.call(via_tuple(room_name), {:solution_found, room_name, player_name, moved_robots, moves, verbose_move_list})
      broadcast_clock(state)
      state.robots
    else
      moved_robots
    end
  end


  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end


  @impl true
  def handle_call({:solution_found, room_name, player_name, moved_robots, moves, verbose_move_list}, _from, state) do

    num_robots =
      moves
      |> Enum.uniq_by(fn %{"color" => c} -> c end)
      |> Enum.count()

    num_moves = moves |> Enum.count()

    return_state =
      if state.solution_found do
        if num_moves < state.solution_moves || (num_moves == state.solution_moves && num_robots > state.solution_robots) do
          Room.system_chat(room_name, "An improved, #{num_robots}-robot, #{num_moves}-move solution has been found.")

          %{ state
             | solution_moves: num_moves,
               solution_robots: num_robots,
               best_solution_player_name: player_name,
               best_solution_robots: moved_robots,
               best_solution_moves: verbose_move_list
           }
        else
          state
        end
      else
        Room.system_chat(room_name, "A #{num_robots}-robot, #{num_moves}-move solution has been found.")
        %{ state | solution_found: true, solution_moves: num_moves, solution_robots: num_robots, best_solution_player_name: player_name, best_solution_robots: moved_robots, best_solution_moves: verbose_move_list }
      end

    # return robots to original locations, but update the state with new solution
    {:reply, return_state, return_state}
  end

  @doc "Tick 1 second"
  @impl GenServer
  def handle_info(:timerevent, state) do
    countdown = state.current_countdown - if state.solution_found, do: 1, else: 0
    timer = state.current_timer + 1

    new_state =
      if countdown <= 0 do
        finish_round(state)
      else
        %{state | current_countdown: countdown, current_timer: timer}
      end


    {:noreply, new_state}
  end

  # Returned with a message (status) from the solver
  def handle_info({_pid, status}, state) do
    {:noreply, state}
  end

  # Returned after solver dies, whether successfully or not
  def handle_info({:DOWN, _ref, :process, _object, _reason}, state) do
    {:noreply, state}
  end

  def finish_round(state) do
    if state.solution_robots > 1 || state.solution_moves >= state.setting_min_moves do
      Room.add_points(state.room_name, state.best_solution_player_name, 1)
      Room.system_chat(state.room_name, "#{state.best_solution_player_name} won with a #{state.solution_robots}-robot, #{state.solution_moves}-move solution.")
      Room.broadcast_scoreboard(state.room_name)
    else
      Room.system_chat(state.room_name, "#{state.best_solution_player_name} found a #{state.solution_robots}-robot, #{state.solution_moves}-move solution but receives no points.")
    end
    Room.system_message(state.room_name, %{url: GameLogic.get_svg_url(state)}, "system_chat_svg")

    new_round(state)
  end

  defp via_tuple(room_name) do
    {:via, Registry, {Registry.GameRegistry, room_name}}
  end

  
end

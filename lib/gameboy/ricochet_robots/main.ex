defmodule Gameboy.RicochetRobots.Main do
  @moduledoc """
  Ricochet Robots game components, including settings, solving, game state, etc.

  Consider splitting new_game, new_board, and new_round.
  """

  use GenServer
  require Logger

  alias Gameboy.{Player, Room, GameSupervisor}
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
            setting_puzzles_before_new: 10,
            # new board generated after this many more puzzles
            current_puzzles_until_new: 10,
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
            best_solution_player_name: nil

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
          best_solution_player_name: String.t()
        }

  @typedoc "Position: { row: Integer, col: Integer }"
  @type position_t :: %{x: integer, y: integer}

  @typedoc "Goal: { pos: position, symbol: String, active: boolean }"
  @type goal_t :: %{pos: position_t, symbol: String.t(), active: boolean}

  @typedoc "Move"
  @type move_t :: %{color: String.t(), direction: String.t()}

  @typedoc "Robot: { pos: position, color: String, moves: [move] }"
  @type robot_t :: %{pos: position_t, color: String.t(), moves: [move_t]}

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
    Logger.info("[[Ricochet Robots]] Started for [#{room_name}].")
    {visual_board, boundary_board, goals} = GameLogic.populate_board()
    robots = GameLogic.populate_robots()

    state = %__MODULE__{
      room_name: room_name,
      boundary_board: boundary_board,
      visual_board: visual_board,
      goals: goals,
      robots: robots
    }
    

    :timer.send_interval(5000, :timerevent)

    {:ok, state}
  end

  @doc """
  Begin a new game (new boards, new robot positions, new goal positions).

  Broadcast new game information and clear all move queues.
  """
  @spec new(room_name: String.t()) :: nil
  def new(room_name) do
    GameSupervisor.start_link(%{room_name: room_name})

    # Room.system_chat(room_name, "A new game of Ricochet Robots is starting!")

    # broadcast_new_game(room_name)
    # broadcast_visual_board(room_name)
    # broadcast_robots(room_name)
    # broadcast_goals(room_name)
    # broadcast_clock(room_name)
    # clear_moves(room_name)
  end

  def new_round(room_name) do
    GenServer.cast(via_tuple(room_name), :new_round)
  end

# GAME?
  @spec fetch(String.t()) :: {:ok, __MODULE__.t()} | :error
  def fetch(game_name) do
    
    Logger.debug("There are now THIS MANY GAMES: #{inspect(Registry.count(Registry.GameRegistry))}.")
    Logger.debug("Time to look up the game #{inspect( via_tuple(game_name) )}")
    case GenServer.whereis(via_tuple(game_name)) do
      nil -> :error

      _proc -> 
        Logger.debug("looking for #{inspect( via_tuple(game_name) )}")
        case GenServer.call(via_tuple(game_name), :get_state) do
          {:ok, game} -> {:ok, game}
          _ -> :error
        end
      end

  end

  def broadcast_new_game(room_name) do
    message = Poison.encode!(%{action: "new_game"})
    GenServer.cast(via_tuple(room_name), {:broadcast_to_players, message})
  end

  def broadcast_visual_board(room_name) do
    {:ok, state} = fetch(room_name)

    message = Poison.encode!(%{action: "update_board", content: state.visual_board})
    GenServer.cast(via_tuple(room_name), {:broadcast_to_players, message})
  end

  def broadcast_robots(room_name) do
    {:ok, state} = fetch(room_name)
    message = Poison.encode!(%{action: "update_robots", content: state.robots})
    GenServer.cast(via_tuple(room_name), {:broadcast_to_players, message})
  end

  def broadcast_goals(room_name) do
    {:ok, state} = fetch(room_name)
    message = Poison.encode!(%{action: "update_goals", content: state.goals})
    GenServer.cast(via_tuple(room_name), {:broadcast_to_players, message})
  end

  @doc """
  Send out the current clock information.

  If a solution has been found, the clock should switch to "countdown" mode.
  Otherwise, the clock continues running in "timer" mode.

  At certain times, such as when a new user joins or the clock is reset, it is
  necessary to broadcast the true timer information. Otherwise, the client can
  handle ticking the timer.
  """
  def broadcast_clock(room_name) do
    {:ok, state} = fetch(room_name)

    message =
      Poison.encode!(%{
        action: if(state.solution_found, do: "switch_to_countdown", else: "switch_to_timer"),
        content: %{timer: state.current_timer, countdown: state.current_countdown}
      })

    GenServer.cast(via_tuple(room_name), {:broadcast_to_players, message})
  end

  @doc """
  Send out command to clear queue of moves. At a new game, for example, all
  queued moves should be forced to clear.
  """
  def clear_moves(room_name) do
    message = Poison.encode!(%{action: "clear_moves_queue", content: ""})
    GenServer.cast(via_tuple(room_name), {:broadcast_to_players, message})
  end

  @doc """
  Award a point to the winning solution, but only if the solution is good enough.

  `state.setting_min_moves` determines the minimum number of moves required for
  a single-robot solution to earn a point. All solutions involves more than two
  robots are scored.
  """
  def award_points(room_name) do
    GenServer.cast(via_tuple(room_name), :award_points)
  end


  @impl true
  def handle_cast({:broadcast_to_players, message}, state) do
    Room.broadcast_to_players(message, state.room_name)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:new_round, _state) do
  end

  @impl true
  def handle_cast(:award_points, state) do
    winner = Player.fetch(state.best_solution_player_name)

    if state.solution_robots > 1 || state.solution_moves >= state.setting_min_moves do
      Room.system_chat(
        state.registry_key,
        "#{winner.username} won with a #{state.solution_robots}-robot, #{state.solution_moves}-move solution."
      )

      # TODO ############### return_user = %{winner | score: winner.score + 1}
      # TODO ############### Room.update_user(return_user)
      Room.broadcast_scoreboard(state.registry_key)
    else
      Room.system_chat(
        state.registry_key,
        "#{winner.username} found a #{state.solution_robots}-robot, #{state.solution_moves}-move solution but receives no points."
      )
    end

    {:noreply, state}
  end

  @doc """
  Accept a set of moves from the user. Get the next set of valid moves.

  Also check whether the submitted set of moves is a solution to the board. If
  it is a valid solution, update the round state accordingly.
  """
  @spec move_robots(String.t(), String.t(), [move_t]) :: [robot_t]
  def move_robots(room_name, player_name, moves) do
    {:ok, state} = fetch(room_name)

    Logger.debug("Its my job to do #{inspect moves}")
    # if GameLogic.check_solution(moves, state.goals) do
    #   GenServer.call(via_tuple(room_name), {:solution_found, moves, player_name})
    #   broadcast_clock(room_name)
    #   state.robots
    # else
    #   GameLogic.make_move(state.robots, state.boundary_board, moves)
    # end

    
    test = GameLogic.make_move(state.robots, state.boundary_board, moves)

    Logger.debug("FINISHED MAKE MOVES. DELETE")

    test

    
  end





  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end



  @impl true
  def handle_call({:solution_found, moves, player_name}, from, state) do
    num_robots =
      moves
      |> Enum.uniq_by(fn %{"color" => c} -> c end)
      |> Enum.count()

    num_moves = moves |> Enum.count()

    return_state =
      if state.solution_found do
        if num_moves < state.solution_moves ||
             (num_moves == state.solution_moves && num_robots > state.solution_robots) do
          Room.system_chat(
            state.registry_key,
            "An improved, #{num_robots}-robot, #{num_moves}-move solution has been found."
          )

          %{
            state
            | solution_moves: num_moves,
              solution_robots: num_robots,
              best_solution_player_name: player_name
          }
        else
          state
        end
      else
        Room.system_chat(
          state.registry_key,
          "A #{num_robots}-robot, #{num_moves}-move solution has been found."
        )

        response =
          Poison.encode!(%{
            content: "",
            action: "clear_moves_queue"
          })

        Registry.Gameboy
        |> Registry.dispatch(state.registry_key, fn entries ->
          for {pid, _} <- entries do
            if pid == from |> elem(0) do
              Process.send(pid, response, [])
            end
          end
        end)

        %{
          state
          | solution_found: true,
            solution_moves: num_moves,
            solution_robots: num_robots,
            best_solution_player_name: player_name
        }
      end

    # return robots to original locations, but update the state with new solution
    {:reply, state.robots, return_state}
  end

  @doc "Tick 1 second"
  @impl GenServer
  def handle_info(:timerevent, state) do
    countdown = state.current_countdown - if state.solution_found, do: 1, else: 0
    timer = state.current_timer + 1

    # if countdown <= 0, do: finish_round(state.room_name)

    {:noreply, %{state | current_countdown: countdown, current_timer: timer}}
  end

  def finish_round(room_name) do
    award_points(room_name)
    # TODO: some kind of display!!!
  end

  defp via_tuple(room_name) do
    {:via, Registry, {Registry.GameRegistry, room_name}}
    # {:via, Registry.GameRegistry, {__MODULE__, room_name}}
  end

  
end

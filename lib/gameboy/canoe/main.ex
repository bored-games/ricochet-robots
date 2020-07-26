defmodule Gameboy.Canoe.Main do
  @moduledoc """
  Canoe game components, including settings, solving, game state, etc.

  Consider splitting new_game, new_board, and new_round.
  """

  use GenServer
  require Logger

  alias Gameboy.{Room, GameSupervisor}
  alias Gameboy.Canoe.{GameLogic}

  defstruct room_name: nil,
            board: nil,
            selected_reds: MapSet.new(),
            selected_blues: MapSet.new(),
            current_team: 1, # 1 is red, 2 is blue
            # Time in seconds after a solution is found (60, 6 for testing)
            setting_countdown: 6,
            # 1-robot solutions below this value should not count
            current_countdown: 6,
            # current timer
            current_timer: 0,
            # boolean: has solution been found
            solution_found: false,
            red: nil,
            blue: nil

  @type t :: %{
          room_name: String.t(),
          board: map,
          selected_reds: MapSet.t( {integer, integer} ),
          selected_blues: MapSet.t( {integer, integer} ),
          current_team: 1 | 2,
          setting_countdown: integer,
          current_countdown: integer,
          current_timer: integer,
          solution_found: boolean,
          red: String.t(),
          blue: String.t()
        }

  @typedoc "Position: { row: Integer, col: Integer }"
  @type position_t :: %{x: integer, y: integer}

  def start_link(%{room_name: room_name} = opts) do
    Logger.debug("Registering game with #{inspect via_tuple(room_name)}")
    GenServer.start_link(__MODULE__, opts, name: via_tuple(room_name))
  end

  @impl true
  @spec init(%{room_name: pid()}) :: {:ok, %__MODULE__{}}
  def init(%{room_name: room_name} = _opts) do
    Logger.info("[#{room_name}: Canoe] New game initialized.")
    
    state = new_round(%__MODULE__{room_name: room_name})
    :timer.send_interval(1000, :timerevent)

    {:ok, state}
  end

  @doc """
  Begin a new game. Broadcast new game information.
  """
  @spec new(room_name: String.t()) :: nil
  def new(room_name) do
    Logger.debug("Starting Canoe in [#{inspect room_name}]")
    GameSupervisor.start_child(__MODULE__, %{room_name: room_name})
    # Room.system_chat(room_name, "A new game of Canoe is starting!")
  end

  def new_round(state) do
    
    new_state = %{ state | board: GameLogic.populate_board(), current_timer: 0 }

    broadcast_board(new_state)
    broadcast_clock(new_state)

    new_state
  end


  @doc """
  Game functions that *have* to be sent out when a client joins, i.e. send out the board
  """
  @spec welcome_player(__MODULE__.t(), String.t()) :: :ok
  def welcome_player(state, _player_name) do
    broadcast_board(state)
    broadcast_clock(state)
    broadcast_turn(state)
    :ok
  end

  def handle_game_action(action, content, socket_state) do
    {:ok, state} = fetch(socket_state.room_name)

    case action do
      "submit_movelist" -> 
        case GenServer.call(via_tuple(socket_state.room_name), {:make_move, socket_state.player_name, content}) do
          {:ok, new_board} -> Poison.encode!(%{content: new_board, action: "update_board"})
          # TODO :error_not_your_turn -> etc
        end
      "set_team" -> # TODO: logic/security here... only allow team changes when appropriate...
        case Room.set_team(socket_state.room_name, socket_state.player_name, content) do
          :ok -> 
            broadcast_turn(state)
            Room.broadcast_scoreboard(socket_state.room_name)
            Poison.encode!(%{content: "OK", action: "update_teams"})
          _ ->
            Room.broadcast_scoreboard(socket_state.room_name)
            Poison.encode!(%{content: "OK", action: "update_teams"})
        end
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

  def broadcast_board(state) do
    board = for {_k, v} <- state.board, do: for({_kk, vv} <- v, do: vv) # convert maps to arrays before sending
    message = Poison.encode!(%{action: "update_board", content: board})
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

  def broadcast_turn(state) do
    text = 
      if state.current_team == 1 do
        "Red player's turn"
      else
        "Blue player's turn"
      end
    message = Poison.encode!(%{action: "update_message", content: text})
    GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
  end

  @impl true
  def handle_cast({:broadcast_to_players, message}, state) do
    Room.broadcast_to_players(message, state.room_name)
    {:noreply, state}
  end

  
  @impl true
  def handle_call({:make_move, teamid, [x, y]}, _from, state) do

    Logger.debug("MAKIN MOVES #{inspect teamid} #{inspect [x, y]}")

    # TODO if team_id IS the current team... and IF the move hasn't been made... big case statement here.
    new_board = GameLogic.make_move(state.board, state.current_team, {x, y})
    {selected_reds, selected_blues} =
      case state.current_team do
        1 -> { MapSet.put(state.selected_reds, {x, y}), state.selected_blues }
        2 -> { state.selected_reds, MapSet.put(state.selected_blues, {x, y}) }
      end

    num_canoes =
     case state.current_team do
        1 -> GameLogic.check_solution(new_board, selected_reds, {x, y})
        2 -> GameLogic.check_solution(new_board, selected_blues, {x, y})
      end

    Logger.debug("This gave #{inspect num_canoes} CANOES!!!")
    # check for solutions!!
    # if GameLogic.check_solution(moved_robots, state.goals) do
    #   state = GenServer.call(via_tuple(room_name), {:solution_found, room_name, player_name, moved_robots, moves, verbose_move_list})
    #   broadcast_clock(state)
    #   state.robots
    # end
    state = %{state | board: new_board, selected_reds: selected_reds, selected_blues: selected_blues, current_team: 3 - state.current_team }
    json_board = for {_k, v} <- state.board, do: for({_kk, vv} <- v, do: vv) # convert maps to arrays before sending
    broadcast_board(state)
    broadcast_turn(state)
    {:reply, {:ok, json_board}, state}
  end

  
  @impl true
  def handle_call({:set_team, player, teamid}, _from, state) do

    Logger.debug("SETTING TEAM #{inspect player} #{inspect teamid}")
    {red, blue} =
      case teamid do
        1 -> {player, state.blue}
        2 -> {state.red, player}
        _ -> {state.red, state.blue}
      end
    
    state = %{state | red: red, blue: blue }

    {:reply, {:ok, red, blue}, state}
  end

    
  @doc """
  Accept a set of moves from the user. Get the next set of valid moves.

  Also check whether the submitted set of moves is a solution to the board. If it is a valid solution, update the round state accordingly.
  """
  @spec make_move(String.t(), String.t(), {integer, integer}) :: map
  def make_move(room_name, mover, [x, y]) do
    Logger.debug("MAKIN MOVES #{inspect room_name} #{inspect mover} #{inspect [x, y]}")
    {:ok, state} = fetch(room_name)

    # if player_name IS the current player...
    new_board = GameLogic.make_move(state.board, state.current_team, [x, y])
    # check for solutions!!
    # if GameLogic.check_solution(moved_robots, state.goals) do
    #   state = GenServer.call(via_tuple(room_name), {:solution_found, room_name, player_name, moved_robots, moves, verbose_move_list})
    #   broadcast_clock(state)
    #   state.robots
    # else
    #   moved_robots
    # end

  end



  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  
  @doc "Tick 1 second"
  @impl GenServer
  def handle_info(:timerevent, state) do
    countdown = state.current_countdown - if state.solution_found, do: 1, else: 0
    timer = state.current_timer + 1

    {:noreply, state}
  end

  defp via_tuple(room_name) do
    {:via, Registry, {Registry.GameRegistry, room_name}}
  end
  
end

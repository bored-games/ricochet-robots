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
            complete_red_canoes: [],
            complete_blue_canoes: [],
            current_team: 1, # 1 is red, 2 is blue
            game_over: false,
            setting_countdown: 6,
            current_countdown: 6,
            current_timer: 0,
            red: nil,
            blue: nil,
            ready_for_new_game: %{red: false, blue: false}

  @type t :: %{
          room_name: String.t(),
          board: map,
          selected_reds: MapSet.t( {integer, integer} ),
          selected_blues: MapSet.t( {integer, integer} ),
          complete_red_canoes: [],
          complete_blue_canoes: [],
          current_team: 1 | 2,
          game_over: boolean,
          setting_countdown: integer,
          current_countdown: integer,
          current_timer: integer,
          red: String.t() | nil | :bot,
          blue: String.t() | nil | :bot,
          ready_for_new_game: %{red: boolean, blue: boolean}
        }
        
  @typedoc "canoe: ..."
  @type canoe_t :: {{integer, integer}, {integer, integer}, {integer, integer}, {integer, integer}}

  def start_link(%{room_name: room_name} = opts) do
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
    new_state = %{ state | board: GameLogic.populate_board(),
                           current_timer: 0,
                           selected_reds: MapSet.new(),
                           selected_blues: MapSet.new(),
                           complete_red_canoes: [],
                           complete_blue_canoes: [],
                           current_team: Enum.random([1, 2]), # 1 is red, 2 is blue
                           game_over: false,
                           ready_for_new_game: %{red: false, blue: false}
                           }

    message = Poison.encode!(%{action: "new_game", content: ""})
    GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
    broadcast_board(new_state)
    broadcast_clock(new_state)
    broadcast_turn(new_state)

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
    {:ok, _state} = fetch(socket_state.room_name)

    #Todo: only send poison response if necessary, else :noreply..
    case action do
      "submit_movelist" -> 
        case GenServer.call(via_tuple(socket_state.room_name), {:make_move, socket_state.player_name, content}) do
          :ok -> Poison.encode!(%{content: "ok", action: "update_board"})
          :make_bot_move_now ->
            case GenServer.call(via_tuple(socket_state.room_name), {:call_python_bot}) do
              :ok ->
                Poison.encode!(%{content: "ok", action: "update_board"})
              _ ->
                Poison.encode!(%{content: "The bot FAILED to move correctly.", action: "update_flash_msg"})
            end
          {:error, err_msg} -> Poison.encode!(%{content: err_msg, action: "update_flash_msg"})
        end
      "resign" -> 
        case GenServer.call(via_tuple(socket_state.room_name), {:resign, socket_state.player_name}) do
          :ok -> Poison.encode!(%{content: "ok", action: "resign"})
          {:error, err_msg} -> Poison.encode!(%{content: err_msg, action: "update_flash_msg"})
        end
      "new_game" -> 
        case GenServer.call(via_tuple(socket_state.room_name), {:new_game, socket_state.player_name}) do
          :ok -> Poison.encode!(%{content: "Waiting for opponent...", action: "update_message"})
          {:error, err_msg} -> Poison.encode!(%{content: err_msg, action: "update_flash_msg"})
        end
      "set_team" -> # TODO: logic/security here... only allow team changes when appropriate...?
        case GenServer.call(via_tuple(socket_state.room_name), {:set_team, socket_state.player_name, content}) do
          :ok -> Poison.encode!(%{content: "ok", action: "update_teams"})
          {:error, err_msg} -> Poison.encode!(%{content: err_msg, action: "update_flash_msg"})
        end
      "add_bot" -> # TODO: security
        case GenServer.call(via_tuple(socket_state.room_name), {:add_bot, content}, 15000) do
          :ok -> Poison.encode!(%{content: "ok", action: "update_teams"})
          :make_bot_move_now ->
            case GenServer.call(via_tuple(socket_state.room_name), {:call_python_bot}, 15000) do
              :ok ->
                Poison.encode!(%{content: "ok", action: "update_board"})
              _ ->
                Poison.encode!(%{content: "The bot FAILED to move correctly.", action: "update_flash_msg"})
            end
          {:error, err_msg} -> Poison.encode!(%{content: err_msg, action: "update_flash_msg"})
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
        action: "switch_to_countdown",
        content: %{timer: state.current_timer, countdown: state.current_countdown}
      })
    GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
  end

  def broadcast_turn(state) do
    text = 
      cond do
        state.game_over ->
          "Select New Game to continue."

        state.current_team == 1 ->
          "Red player's turn"
      
        state.current_team == 2 ->
          "Blue player's turn"

        true ->
          ""
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
  def handle_call({:make_move, player_name, [x, y]}, _from, state) do
    case Room.fetch(state.room_name) do
      {:ok, room} -> 
        case Map.fetch(room.players, player_name) do
          {:ok, room_player} ->
            Logger.debug("[Canoe] Team #{inspect state.current_team} (#{inspect player_name}) selects #{inspect [x, y]}")
            
            cond do
              state.game_over ->
                {:reply, {:error, "Select New Game to continue."}, state}

              state.current_team != room_player.team ->
                {:reply, {:error, "It's not your turn!"}, state}

              true ->
                case GameLogic.make_move(state.board, state.current_team, {x, y}) do
                  :error_not_valid_move ->
                    {:reply, {:error, "Invalid move!"}, state}
  
                  new_board ->
                    message = Poison.encode!(%{action: "update_last_move", content: [x, y]})
                    GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
                    
                    {selected_pieces, complete_canoes, team_name} = 
                      case state.current_team do
                        1 -> {MapSet.put(state.selected_reds, {x, y}), state.complete_red_canoes, "Red"}
                        2 -> {MapSet.put(state.selected_blues, {x, y}), state.complete_blue_canoes, "Blue"}
                      end

                    {count_all, count_new, complete_canoes} = GameLogic.check_solution(complete_canoes, selected_pieces, {x, y})
  
                    {status, state} =
                      if count_all >= 2 do
                          message = Poison.encode!(%{action: "game_over", content: "#{team_name} wins!"})
                          GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
                          Room.add_points(state.room_name, player_name, 1)
                          Room.broadcast_scoreboard(state.room_name)
  
                          {:ok, %{state | game_over: true, board: new_board}}
                      else 
                        if count_new >= 1 do
                          message = Poison.encode!(%{action: "update_flash_msg", content: "#{team_name} found a new canoe!"})
                          GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
                        end
                        state =
                          case state.current_team do
                            1 -> %{state | selected_reds: selected_pieces, complete_red_canoes: complete_canoes}
                            2 -> %{state | selected_blues: selected_pieces, complete_blue_canoes: complete_canoes}
                          end
                          
                        state = %{state | board: new_board, current_team: 3-state.current_team }
                        broadcast_turn(state)
                        status =
                          if state.current_team == 1 do
                            if state.red == :bot do
                              :make_bot_move_now
                            else
                              :ok
                            end
                          else
                            if state.blue == :bot do
                              :make_bot_move_now
                            else
                              :ok
                            end
                        end
                        {status, state}
                      end
  
                    # if game is over, bots need to ready for new game
                    state = 
                      if state.game_over do
                        if state.red == :bot do
                          Logger.debug("setting red ready")
                          %{ state | ready_for_new_game: %{ state.ready_for_new_game | red: true }}
                        end
                        if state.blue == :bot do
                          Logger.debug("setting blue ready")
                          %{ state | ready_for_new_game: %{ state.ready_for_new_game | blue: true }}
                        end
                      else
                        state
                      end

                    broadcast_board(state)
                    {:reply, status, state}
                  end
            end
            
          :error ->
            {:reply, {:error, "Error finding #{inspect player_name} in #{inspect state.room_name}"}, state}
        end

      _ ->
        Logger.debug("Could not find room #{inspect state.room_name}")
        {:reply, {:error, "Unknown room"}, state}
    end

  end


  @impl true
  def handle_call({:call_python_bot}, _from, state) do
    case Room.fetch(state.room_name) do
      {:ok, _room} ->
        {x, y} = Gameboy.PyWorker.canoe_ai(MapSet.to_list(state.selected_reds), MapSet.to_list(state.selected_blues), state.current_team)
        Logger.debug("[Canoe] Team #{inspect state.current_team} bot chooses: #{inspect [x, y]}")

        cond do
          state.game_over ->
            {:reply, {:error, "Select New Game to continue."}, state} # TODO: bot should automatically select new game...

          true ->
            case GameLogic.make_move(state.board, state.current_team, {x, y}) do
              :error_not_valid_move ->
                {:reply, {:error, "Invalid move!"}, state}

              new_board ->
                message = Poison.encode!(%{action: "update_last_move", content: [x, y]})
                GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
                
                {selected_pieces, complete_canoes, team_name} = 
                  case state.current_team do
                    1 -> {MapSet.put(state.selected_reds, {x, y}), state.complete_red_canoes, "Red"}
                    2 -> {MapSet.put(state.selected_blues, {x, y}), state.complete_blue_canoes, "Blue"}
                  end

                {count_all, count_new, complete_canoes} = GameLogic.check_solution(complete_canoes, selected_pieces, {x, y})

                {status, state} =
                  if count_all >= 2 do
                      message = Poison.encode!(%{action: "game_over", content: "#{team_name} wins!"})
                      GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})

                      # Room.add_points(state.room_name, player_name, 1) # maybe add points to bot
                      Room.broadcast_scoreboard(state.room_name)

                      {:ok, %{state | game_over: true, board: new_board}}
                  else 
                    if count_new >= 1 do
                      message = Poison.encode!(%{action: "update_flash_msg", content: "#{team_name} found a new canoe!"})
                      GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})
                    end
                    state =
                      case state.current_team do
                        1 -> %{state | selected_reds: selected_pieces, complete_red_canoes: complete_canoes}
                        2 -> %{state | selected_blues: selected_pieces, complete_blue_canoes: complete_canoes}
                      end
                      
                    state = %{state | board: new_board, current_team: 3-state.current_team }
                    broadcast_turn(state)
                    {:ok, state}
                  end

                broadcast_board(state)
                {:reply, status, state}
              end
        end



      _ ->
        Logger.debug("Could not find room #{inspect state.room_name}")
        {:reply, {:error, "Unknown room"}, state}
    end

  end


  @impl true
  def handle_call({:set_team, player, teamid}, _from, state) do
    case Room.set_team(state.room_name, player, teamid) do
      :ok -> 
        {red, blue} =
          case teamid do
            1 -> {player, state.blue}
            2 -> {state.red, player}
            _ -> {state.red, state.blue}
          end
        state = %{state | red: red, blue: blue }
      
        broadcast_turn(state)
        Room.broadcast_scoreboard(state.room_name)
        {:reply, :ok, state}
      _ ->
        Room.broadcast_scoreboard(state.room_name)
        {:reply, {:error, "Unable to set team"}, state}
    end
  end
  
  @impl true
  def handle_call({:add_bot, team_id}, _from, state) do
    case Room.add_bot(state.room_name, "canoebot", team_id) do
      :ok ->
        _response = Gameboy.PyWorker.init_canoe_ai()
        state =
          case team_id do
            1 -> %{state | red: :bot }
            2 -> %{state | blue: :bot }
            _ -> state
          end
      
        broadcast_turn(state)
        Room.broadcast_scoreboard(state.room_name)
        if state.current_team == team_id do
          {:reply, :make_bot_move_now, state}
        else
          {:reply, :ok, state}
        end
      _ ->
        Room.broadcast_scoreboard(state.room_name)
        {:reply, {:error, "Unable to create bot"}, state}
    end
  end

  
  @impl true
  def handle_call({:resign, player}, _from, state) do
    Logger.debug("RESIGN BY #{inspect player} R: #{inspect state.red} B: #{inspect state.blue}")

    cond do
      state.game_over ->
        {:reply, {:error, "Error: the game is already over."}, state}

      player != state.red and player != state.blue ->  
        {:reply, {:error, "Error: you don't seem to be playing."}, state}

      true ->
        message = Poison.encode!(%{action: "game_over", content: "#{player} has resigned!"})
        GenServer.cast(via_tuple(state.room_name), {:broadcast_to_players, message})

        opponent = if (state.red == player), do: state.blue, else: state.red

        Room.add_points(state.room_name, opponent, 1)
        Room.broadcast_scoreboard(state.room_name)
        state = %{state | game_over: true}
        {:reply, :ok, state}
      end
  end

  
  
  @impl true
  def handle_call({:new_game, player}, _from, state) do

    Logger.debug("[Canoe] #{inspect player} is ready for a new game")

    cond do
      player != state.red and player != state.blue ->  
        {:reply, {:error, "Error: you don't seem to be playing."}, state}

      true ->
        ready =
          cond do
            player == state.red ->
              %{state.ready_for_new_game | red: true}
            
            player == state.blue ->
              %{state.ready_for_new_game | blue: true}
          end
        
        if ready == %{red: true, blue: true} do
          new_game = new_round(state) 
          {:reply, :ok, new_game}
        else
          {:reply, :ok, %{state | ready_for_new_game: ready}}
        end
        
      end
  end

    


  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  
  @doc "Tick 1 second"
  @impl GenServer
  def handle_info(:timerevent, state) do

    

    {:noreply, state}
  end

  defp via_tuple(room_name) do
    {:via, Registry, {Registry.GameRegistry, room_name}}
  end
  
end

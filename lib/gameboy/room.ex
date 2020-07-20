defmodule ChatLog do
  @moduledoc """
  A wrapper around a list that enforces a maximum list length. After the
  maximum length is reached, new additions to the list will push the
  old elements into the void.
  """

  @max_length 1000

  defstruct list: [],
            length: 0

  @type t :: %{
          list: [],
          length: integer
        }

  def new(), do: %__MODULE__{}

  def log(chat_list, element) do
    list = [element | chat_list.list]

    if chat_list.length == @max_length do
      %__MODULE__{list: Enum.slice(list, 0, @max_length), length: @max_length}
    else
      %__MODULE__{list: list, length: chat_list.length + 1}
    end
  end
end



defmodule Gameboy.Room do
  @moduledoc """
  Defines a `Room`.

  A `Room` is a GenServer that contains information about current players, chat, and can
  have up to one `game` (`Gameboy.Game`) attached.

  TODO: Add more functions that we need:
  - Get chat history
  - Mute user
  - Unmute user
  - Private (unlisted) rooms

  """
  
  # TODO: Add more words.

  @room_name_word_list [
    "Banana",
    "Apple",
    "Orange",
    "Crackers",
    "Cheese"
  ]

  use GenServer
  require Logger

  alias Gameboy.{Player, RoomSupervisor}
  alias Gameboy.RicochetRobots.Main, as: RicochetRobots

  @default_player_limit 10

  defstruct name: nil,
            player_limit: @default_player_limit,
            players: %{},
            game: nil,
            chat: ChatLog.new()

  @type t :: %{
          name: String.t(),
          player_limit: integer,
          players: %{
            required(String.t()) => %{
              score: integer,
              is_admin: boolean,
              is_muted: boolean
            }
          },
          game: String.t(),
          chat: ChatLog.t()
        }

  def start_link(opts) do
    room_name = Map.get(opts, :room_name)

    {:ok, _} = GenServer.start_link(__MODULE__, opts, name: via_tuple(room_name))
  end

  @impl true
  # @spec init(%{room_name: String.t()}) :: {:ok, %__MODULE__{}}
  def init(opts) do
    
    room_name = opts[:room_name]

    state = %__MODULE__{
      name: room_name,
      player_limit: Map.get(opts, :player_limit, @default_player_limit)
    }

    
    Logger.info("[#{room_name}] Opened new room.")

    state =
      if game_name = opts[:start_game] do
        case start_game(room_name, game_name) do
          {:ok, _game} -> %{state | game: game_name}
          :error -> state
        end
      else
        Logger.info("No game to start!")
        state
      end


    {:ok, state}
  end

  @doc """
  Create a new room and return its name.
  """
  def new(opts) do
    room_name = generate_name()

    opts = Map.put(opts, :room_name, room_name)

    Logger.debug("Attempting to create room through Room.new() with name \"#{room_name}\" and opts #{inspect(opts)}.")
    RoomSupervisor.start_link(opts)
    # system_chat(room_name, "Welcome to #{room_name}!")

    room_name
  end

  
  @spec fetch(String.t()) :: {:ok, __MODULE__.t()} | :error
  def fetch(room_name) do
    case GenServer.whereis(via_tuple(room_name)) do
      nil -> :error
      _proc -> 
        case GenServer.call(via_tuple(room_name), :get_state) do
          {:ok, player} -> {:ok, player}
          _ -> :error
        end
      end
  end



  def close(room_name) do
    Logger.info("Preparing for room close: kicking users from room.")

    Registry.dispatch(Registry.RoomPlayerRegistry, room_name, fn entries ->
      for {_pid, player_name} <- entries, do: remove_player(room_name, player_name) # TO DO
    end)

    Logger.debug("Stopping Room, bye bye!")
    GenServer.stop(via_tuple(room_name), :normal)
  end

  def broadcast_to_players(message, room_name) do
    
    # Logger.debug("Did you ever do this? #{inspect Registry.count(Registry.RoomPlayerRegistry)} #{inspect message}")

    Registry.dispatch(Registry.RoomPlayerRegistry, room_name, fn entries ->
      for {pid, _player_name} <- entries, do: Process.send(pid, {:send_json, message}, [])
    end)
  end

  # Add player to room.
  @spec add_player(String.t(), integer) :: :ok | :error
  def add_player(room_name, player_name) do
    Logger.info("[Room.add_player] Adding `#{player_name}` to [#{room_name}]")
    {:ok, _room} = GenServer.call(via_tuple(room_name), {:add_player, player_name})
    :ok
  end

  
  # Add player to room.
  @spec welcome_player(String.t(), integer) :: :ok | :error
  def welcome_player(room_name, player_name) do
    Logger.info("[Room.welcome_player] Welcoming `#{player_name}` to [#{room_name}]")
    {:ok, room} = GenServer.call(via_tuple(room_name), :get_state)
    if room.game do
      case RicochetRobots.fetch(room_name) do
        {:ok, game} -> RicochetRobots.welcome_player(game, player_name)
        :error -> nil
      end
    end
    broadcast_scoreboard(room_name)
    :ok
  end

  @spec get_game_module(String.t()) :: String.t() | :error_no_current_game | :error_unknown_game
  def get_game_module(game_name) do
    case game_name do
      "robots" -> RicochetRobots
      nil -> :error_no_current_game
      _ -> :error_unknown_game
    end
  end
  
  # Start a game...
  @spec start_game(String.t(), String.t()) :: :ok | :error
  def start_game(room_name, game_name) do
    case get_game_module(game_name) do
      :error_unknown_game -> :error
      game_module -> {:ok, game_module.new(room_name)}
    end
  end
  
  @spec add_game(String.t(), integer, String.t()) :: :ok | :error
  def add_game(room_name, player_name, game_name) do
    Logger.info("[Room.add_game] #{player_name} wants to start #{game_name} in #{room_name}")
    GenServer.call(via_tuple(room_name), {:add_game, player_name, game_name})
  end
  
  @spec get_player(String.t(), integer) :: :ok | :error
  def get_player(room_name, player_name) do
    Logger.info("[Room.get_player] #{player_name} in #{room_name}")
    GenServer.call(via_tuple(room_name), {:get_player, player_name})
  end
  
  @spec award_points(String.t(), integer, integer) :: :ok | :error
  def award_points(room_name, player_name, points) do
    GenServer.call(via_tuple(room_name), {:award_points, player_name, points})
  end

  @spec remove_player(String.t(), integer) :: nil
  def remove_player(room_name, player_name) do
    GenServer.call(via_tuple(room_name), {:remove_player, player_name})
  end

  @spec player_chat(String.t(), integer, String.t()) :: nil
  def player_chat(room_name, player_name, message) do
    GenServer.cast(via_tuple(room_name), {:player_chat, player_name, message})
  end

  @spec system_chat(String.t(), String.t(), String.t()) :: nil
  def system_chat(room_name, message, action \\ "system_chat_new_message") do
    GenServer.cast(via_tuple(room_name), {:system_chat, message, action})
  end

  @spec system_chat_to_player(String.t(), integer, String.t()) :: nil
  def system_chat_to_player(room_name, player_name, message, action \\ "system_chat_to_player_new_message") do
    GenServer.cast(via_tuple(room_name), {:system_chat_to_player, player_name, message, action})
  end

  @spec broadcast_scoreboard(String.t()) :: nil
  def broadcast_scoreboard(room_name) do
    GenServer.cast(via_tuple(room_name), :broadcast_scoreboard)
  end

  @spec broadcast_game_info(String.t(), String.t()) :: nil
  def broadcast_game_info(room_name, message) do
    GenServer.cast(via_tuple(room_name), {:broadcast_game_info, message})
  end

  

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end


  @doc """
  Add a player to a room. Check a few things, such as the player limit and the
  existence of a player; after verifying them, add the player to the room.
  """
  @impl true
  def handle_call({:add_player, player_name}, _from, state) do

    if map_size(state.players) == state.player_limit do
      Logger.debug("Room at player limit (#{state.player_limit}), rejecting player \"#{player_name}\".")
      {:reply, :error, state}
    else
      # Make sure player really exists.
      case Player.fetch(player_name) do
        {:ok, player} ->
          
          # TO DO: what if player is already in room?

          Logger.info("[#{state.name} (/#{state.player_limit})] Player \"#{player.name}\" joined.")
          system_chat(state.name, "#{player.name} joined the room.")

          state = %__MODULE__{state | players: Map.put_new(state.players, player.name, %{score: 0, color: player.color, is_admin: false, is_muted: false})} # TO DO!!!
          {:reply, {:ok, state}, state}

        :error ->
          Logger.debug("Player \"#{player_name}\" does not exist, did not add to room.")
          {:reply, :error, state}
      end
    end
  end

  
  @doc """
  Get a player and their status within a room.
  """
  @impl true
  def handle_call({:get_player, player_name}, _from, state) do
    case Player.fetch(player_name) do
      {:ok, player} ->
        case Map.fetch(state.players, player_name) do
          {:ok, room_player} ->
            {:reply, {:ok, Player.to_map(player, room_player.score, room_player.is_admin, room_player.is_muted)}, state}
          :error ->
            {:reply, :error, state}
        end
      :error ->
        {:reply, :error, state}
    end
  end

  
  @doc """
  Add a game to a room. Check if player has the proper authority and if a game already exists.
  """
  @impl true
  def handle_call({:add_game, player_name, game_name}, _from, state) do
    if state.game do
      Logger.debug("Finish your current game first!")
      {:reply, :error, state}
    else
      # Make sure game really exists.
      case start_game(state.name, game_name) do
        {:ok, game} ->

          Logger.info("Player \"#{player_name}\" has begun a game of #{game_name} in `#{state.name}`.")
          # system_chat(state.name, "#{player.name} has begun a game of...")
          state = %__MODULE__{state | game: game}
          
          {:reply, :ok, state}

        :error ->
          Logger.debug("Game \"#{game_name}\" does not exist, did not add to room `#{state.name}`.")
          {:reply, :error, state}
      end
    end
  end
  
  
  @doc """
  Add points to a player in a room.
  """
  @impl true
  def handle_call({:award_points, player_name, points}, _from, state) do
    
    # find player_name and add points.
    # TO DO: handle error...
    new_state = try do
      update_in(state.players[player_name].score, &(&1 + points))
    catch
      _ -> state
    end

    {:reply, :ok, new_state}
  end

  @doc """
  Remove a player from a room. Error if the player is not in the room. If the
  player being removed is the last player in the room, close the room.
  """
  @impl true
  def handle_call({:remove_player, player_name}, _from, state) do
    if Map.has_key?(state.players, player_name) do
      Logger.debug("Removing \"#{player_name}\" from room \"#{state.name}\".")

      Registry.unregister_match(Registry.RoomPlayerRegistry, state.name, player_name)
      state = %__MODULE__{state | players: Map.delete(state.players, player_name)}

      if map_size(state.players) == 0 do
        Logger.info("Last player has left room. Closing.")
        close(state.name)
      end

      {:reply, :ok, state}
    else
      Logger.debug("\"#{player_name}\" not in \"#{state.name}\", did not remove from room.")
      {:reply, :error, state}
    end
  end

  @doc """
  Send a chat message from a player to the room. Dispatch the message to all
  websockets of players currently in the room and save it to the chat log.
  """
  @impl true
  def handle_cast({:player_chat, player_name, chat_message}, state) do
    case Player.fetch(player_name) do
      {:ok, player} ->
        message =
          Poison.encode!(%{
            action: "player_chat_new_message",
            content: %{
              room_name: state.name,
              user: Player.to_map(player, 0, false, false),
              message: chat_message,
              # timestamp: :calendar.universal_time(), # doesn't encode with poison...
               timestamp: DateTime.utc_now()
            }
          })

        broadcast_to_players(message, state.name)

        state = %__MODULE__{state | chat: ChatLog.log(state.chat, message)}
        {:noreply, state}

      :error ->
        {:noreply, state}
    end
  end

  @doc """
  Send a system message to a room. Dispatch the message to all websockets of
  players currently in the room and save it to the chat log.
  """
  @impl true
  def handle_cast({:system_chat, chat_message, action}, state) do
    message =
      Poison.encode!(%{
        action: action,
        content: %{
          room_name: state.name,
          message: chat_message,
         # timestamp: :calendar.universal_time(), # doesn't encode with poison...
          timestamp: DateTime.utc_now()
        }
      })

    Logger.debug("[#{state.name}] System chat: #{inspect chat_message}")
    broadcast_to_players(message, state.name)

    state = %__MODULE__{state | chat: ChatLog.log(state.chat, message)}
    {:noreply, state}
  end

  @doc """
  Send a system message to a specific player in a room. Dispatch the message
  to the websocket of that specific player.
  """
  @impl true
  def handle_cast({:system_chat_to_player, player_name, chat_message, action}, state) do
    message =
      Poison.encode!(%{
        action: action,
        content: %{
          room_name: state.name,
          message: chat_message,
          # timestamp: :calendar.universal_time(), # doesn't encode with poison...
           timestamp: DateTime.utc_now()
        }
      })

    case Player.fetch(player_name) do
      {:ok, player} -> Process.send(player.socket_pid, message, [])
      :error -> nil
    end

    {:noreply, state}
  end

  @doc """
  Broadcast the current scoreboard to all clients in a room.
  """
  @impl true
  def handle_cast(:broadcast_scoreboard, state) do
       
    current_players = Enum.map(state.players, fn {k, v} ->
      case Player.fetch(k) do
        {:ok, player} -> {k, Player.to_map(player, v.score, v.is_admin, v.is_muted)}
        :error -> {k, v}
      end
    end)
    |> Enum.into(%{})

    Logger.debug("[#{state.name}] Broadcast scoreboard to #{map_size current_players} players")

    Poison.encode!(%{action: "update_scoreboard", content: current_players})
    |> broadcast_to_players(state.name)

    {:noreply, state}
  end


  defp via_tuple(room_name) do
    {:via, Registry, {Registry.RoomRegistry, room_name}}
  end

  @spec generate_name() :: String.t()
  defp generate_name() do
    # Generate a random room name from a word list. Compare the room name against
    # existing room names; if there is a conflict, recurse and generate a new name.
    room_name = Enum.random(@room_name_word_list) <> Enum.random(@room_name_word_list)

    case Registry.lookup(Registry.RoomRegistry, room_name) do
      [{_, _}] -> generate_name()
      [] -> room_name
    end
  end
end

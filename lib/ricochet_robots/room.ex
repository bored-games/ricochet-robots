defmodule ChatList do
  @moduledoc """
  A wrapper around a list that enforces a maximum list length. After the
  maximum length is reached, new additions to the list will push the
  old elements into the void.
  """

  # TODO: Add more functions that we need:
  # - Get chat history
  # - End game

  @max_length 1000

  defstruct list: [],
            length: 0

  @type t :: %{
          list: [],
          length: integer
        }

  def new(), do: %__MODULE__{}

  def prepend(chat_list, element) do
    list = [element | chat_list.list]

    if chat_list.length == @max_length do
      %__MODULE__{list: Enum.slice(list, 0, @max_length), length: @max_length}
    else
      %__MODULE__{list: list, length: chat_list.length + 1}
    end
  end
end

defmodule RicochetRobots.Room do
  @moduledoc """
  Defines a `Room`.

  A `Room` is a GenServer that contains information about current players and can
  have up to one `game` (`RicochetRobots.Game`) attached.
  """

  use GenServer
  require Logger

  alias RicochetRobots.Player, as: Player

  @default_player_limit 8

  defstruct name: nil,
            game: nil,
            player_limit: @default_player_limit,
            players: %{},
            chat: ChatList.new()

  @type t :: %{
          name: String.t(),
          game: Game.t(),
          player_limit: integer,
          players: %{
            required(String.t()) => %{
              score: integer,
              is_admin: boolean,
              is_muted: boolean
            }
          },
          chat: ChatList.t()
        }

  def start_link(%{room_name: room_name} = opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(room_name))
  end

  @impl true
  @spec init(%{room_name: String.t()})
  def init(%{room_name: room_name} = opts) do
    Logger.info("Opened new room.")

    state = %__MODULE__{
      name: room_name,
      player_limit: Map.get(opts, :player_limit, @default_player_limit)
    }

    {:ok, state}
  end

  @doc """
  Create a new room and return it's name.
  """
  def new(opts) do
    room_name = generate_name()

    Logger.debug("Attempting to create room with name \"#{room_name}\".")
    RoomSupervisor.start_link(%{opts | room_name: room_name})
    system_chat(room_name, "Welcome to #{room_name}!")

    room_name
  end

  def close(room_name) do
    Logger.info("Attempting to close room.")

    Logger.debug("Preparing for room close: kicking users from room.")

    Registry.dispatch(Registry.RoomPlayerRegistry, room_name, fn entries ->
      for {player_name, _socket} <- entries, do: remove_player(room_name, player_name)
    end)

    Logger.debug("Stopping GenServer, bye bye!")
    GenServer.stop(via_tuple(room_name), :normal)
  end

  @spec create_game(String.t())
  def create_game(room_name) do
    GenServer.call(via_tuple(room_name), :create_game)
  end

  @spec add_player(String.t(), integer) :: :ok | :error
  def add_player(room_name, player_name) do
    GenServer.call(via_tuple(room_name), {:add_player, player_name})
  end

  @spec remove_player(String.t(), integer)
  def remove_player(room_name, player_name) do
    GenServer.call(via_tuple(room_name), {:remove_player, player_name})
  end

  @spec player_chat(String.t(), integer, String.t())
  def player_chat(room_name, player_name, message) do
    GenServer.cast(via_tuple(room_name), {:player_chat, player_name, message})
  end

  @spec system_chat(String.t(), String.t())
  def system_chat(room_name, message) do
    GenServer.cast(via_tuple(room_name), {:system_chat, message})
  end

  @spec system_chat_to_player(String.t(), integer, String.t())
  def system_chat_to_player(room_name, player, message) do
    GenServer.cast(via_tuple(room_name), {:system_chat_to_player, player, message})
  end

  @spec broadcast_scoreboard(String.t())
  def broadcast_scoreboard(room_name) do
    GenServer.cast(via_tuple(room_name), :broadcast_scoreboard)
  end

  @doc """
  Start a new game in a room. If a game is in-progress, do not start a new game
  and instead return a failure message.
  """
  @impl true
  def handle_call(:create_game, state) do
    game = RicochetRobots.GameSupervisor.start_link(room_name: state.name)
    {:noreply, Map.put(state, :game, game)}
  end

  @doc """
  Add a player to a room. Check a few things, such as the player limit and the
  existence of a player; after verifying them, add the player to the room.
  """
  @impl true
  def handle_call({:add_player, player_name}, state) do
    if map_size(state.players) == state.player_limit do
      Logger.debug("Room at player limit, rejecting player \"#{player_name}\".")
      {:reply, :error, state}
    else
      # Make sure player really exists.
      case Player.fetch(player_name) do
        {:ok, player} ->
          Registry.register(Registry.RoomPlayerRegistry, player_name, player.socket)

          Logger.info("Player \"#{player.name}\" joined.")

          system_chat(room_name, "#{player.name} joined the room.")
          {:reply, :ok, %{state | players: MapSet.put(state.players, player.name)}}

        :error ->
          Logger.debug("Player \"#{player_name}\" does not exist, did not add to room.")
          {:reply, :error, state}
      end
    end
  end

  @doc """
  Remove a player from a room. Error if the player is not in the room. If the
  player being removed is the last player in the room, close the room.
  """
  @impl true
  def handle_call({:remove_player, player_name}, state) do
    if Map.member?(state.players, player_name) do
      Logger.debug("Removing \"#{player_name}\" from room \"#{state.name}\".")

      Registry.unregister(Registry.RoomPlayerRegistry, state.name, player_name)
      state = %{state | Map.delete(state.players, player_name)}

      if map_size(state.players) == 0 do
        Logger.info("Last player has left room. Closing.")
        Room.close(state.name)
      end

      {:reply, :ok, state}
    else
      Logger.debug("\"#{player_name}\" not in \"#{state.name}\", did not remove from room.")
      {:reply, :error, state}
    end
  end

  @impl true
  def handle_cast({:player_chat, player_name, chat_message}, state) do
    case Player.fetch(player_name) do
      {:ok, player} ->
        message =
          Poison.encode!(%{
            action: "player_chat_new_message",
            content: %{
              player_name: player_name,
              message: chat_message,
              timestamp: :calendar.universal_time()
            }
          })

        Registry.dispatch(Registry.RoomPlayerRegistry, state.name, fn entries ->
          for {_, socket} <- entries, do: Process.send(socket, message, [])
        end)

      :error ->
        nil
    end

    state = %{state | chat: ChatList.prepend(state.chat, message)}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:system_chat, chat_message}, state) do
    message =
      Poison.encode!(%{
        action: "system_chat_new_message",
        content: %{
          message: chat_message,
          timestamp: :calendar.universal_time()
        }
      })

    Registry.dispatch(Registry.RoomPlayerRegistry, state.name, fn entries ->
      for {_, socket} <- entries, do: Process.send(socket, message, [])
    end)

    state = %{state | chat: ChatList.prepend(state.chat, message)}
    {:noreply, state}
  end

  @impl true
  def handle_cast(:broadcast_scoreboard, state) do
    message = Poison.encode!(%{content: state.players, action: "update_scoreboard"})

    Registry.dispatch(Registry.RoomPlayerRegistry, state.name, fn entries ->
      for {_, socket} <- entries, do: Process.send(pid, response, [])
    end)

    {:noreply, state}
  end

  defp via_tuple(room_name) do
    {:via, Registry.RoomRegistry, {__MODULE__, room_name}}
  end

  # TODO: Add more words.

  @room_name_word_list [
    "Banana",
    "Apple",
    "Orange",
    "Crackers",
    "Cheese"
  ]

  @doc """
  Generate a random room name from a word list. Compare the room name against
  existing room names; if there is a conflict, recurse and generate a new name.
  """
  @spec generate_name() :: String.t()
  defp generate_name() do
    room_name = Enum.random(@room_name_word_list) <> Enum.random(@room_name_word_list)

    case Registry.lookup(Registry.RoomRegistry, room_name) do
      [{_, _}] -> generate_name()
      [] -> room_name
    end
  end
end

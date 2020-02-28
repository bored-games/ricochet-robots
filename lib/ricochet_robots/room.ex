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
            chat: []

  @type t :: %{
          name: String.t(),
          game: Game.t(),
          player_limit: integer,
          players: %{
            player_id: integer,
            score: integer,
            is_admin: boolean,
            is_muted: boolean
          },
          chat: [String.t()]
        }

  @doc """
  Create a new room and return it's name.
  """
  def new() do
    room_name = generate_name()

    Logger.debug("Attempting to create room with name \"#{room_name}\".")
    RoomSupervisor.start_link(%{opts | room_name: room_name})
    system_chat(room_name, "Welcome to #{room_name}!")

    room_name
  end

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

  @spec create_game(String.t())
  def create_game(room_name),
    do: GenServer.call(via_tuple(room_name), {:create_game})

  @spec add_player(String.t(), integer)
  def add_player(room_name, player_id),
    do: GenServer.call(via_tuple(room_name), {:add_player, player_id})

  @spec remove_player(String.t(), integer)
  def remove_player(room_name, player_id),
    do: GenServer.call(via_tuple(room_name), {:remove_player, player_id})

  @spec broadcast_scoreboard(String.t())
  def broadcast_scoreboard(room_name),
    do: GenServer.cast(via_tuple(room_name), {:broadcast_scoreboard, room_name})

  @spec player_chat(String.t(), integer, String.t())
  def player_chat(room_name, player, message),
    do: GenServer.cast(via_tuple(room_name), {:player_chat, room_name, player, message})

  @spec system_chat(String.t(), String.t())
  def system_chat(room_name, message),
    do: GenServer.cast(via_tuple(room_name), {:system_chat, room_name, message})

  @spec system_chat_to_player(String.t(), integer, String.t())
  def system_chat_to_player(room_name, player, message),
    do: GenServer.cast(via_tuple(room_name), {:system_chat_to_player, room_name, player, message})

  @doc """
  Start a new game in a room. If a game is in-progress, do not start a new game and instead
  return a failure message.
  """
  @impl true
  def handle_call({:create_game}, state) do
    game = RicochetRobots.GameSupervisor.start_link(room_name: state.name)
    Logger.info("New game started.")
    {:noreply, Map.put(state, :game, game)}
  end

  @impl true
  def handle_call({:add_player, player_name}, state) do
    # If we are at player limit, error out.
    if map_size(state.players) == state.player_limit do
      Logger.debug("Room at player limit, rejecting player \"#{player_name}\".")
      {:reply, :error, state}
    else
      # Make sure player really exists.
      case Player.get_player(player_name) do
        {:ok, player} ->
          Logger.info("Player \"#{player.name}\" joined.")
          system_chat(room_name, "#{player.name} joined the room.")
          {:reply, :ok, %{state | players: MapSet.put(state.players, player.name)}}

        :error ->
          Logger.debug("Player \"#{player_name}\" does not exist, did not add to room.")
          {:reply, :error, state}
      end
    end
  end

  @impl true
  def handle_call({:remove_player, key}, state) do
    players = Enum.filter(state.players, fn u -> u.unique_key != key end)
    {:noreply, %{state | players: players}}
  end

  @impl true
  def handle_cast({:broadcast_scoreboard, registry_key}, state) do
    response = Poison.encode!(%{content: state.players, action: "update_scoreboard"})

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:player_chat, registry_key, player, message}, state) do
    response =
      Poison.encode!(%{content: %{player: player, msg: message, kind: 0}, action: "update_chat"})

    # send chat message to all
    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        Process.send(pid, response, [])
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:system_chat, registry_key, message, {pidmatch, message2}}, state) do
    system_player = %{
      playername: "System",
      color: "#c6c6c6",
      score: 0,
      is_admin: false,
      is_muted: false
    }

    json_msg =
      Poison.encode!(%{
        content: %{player: system_player, msg: message, kind: 1},
        action: "update_chat"
      })

    Registry.RicochetRobots
    |> Registry.dispatch(registry_key, fn entries ->
      for {pid, _} <- entries do
        if pid == pidmatch do
          json_msg2 =
            Poison.encode!(%{
              content: %{player: system_player, msg: message2, kind: 1},
              action: "update_chat"
            })

          Process.send(pid, json_msg2, [])
        else
          Process.send(pid, json_msg, [])
        end
      end
    end)

    # store chat in state?
    state = %{state | chat: [message | state.chat]}
    {:noreply, state}
  end

  defp via_tuple(room_name) do
    {:via, Registry.RoomRegistry, {__MODULE__, room_name}}
  end

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
      {:ok, _} -> generate_name()
      [] -> room_name
    end
  end
end

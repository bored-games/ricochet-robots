defmodule Gameboy.Player do
  @moduledoc """
  A `Player` is a user, including any relevant settings or information.

  `color` is a "#rrggbb" string.
  """

  use GenServer
  require Logger
  
  alias Gameboy.{PlayerSupervisor}

  defstruct name: nil,
            nickname: nil,
            private_key: nil,
            color: "#c6c6c6",
            socket_pid: nil,
            rooms: MapSet.new()

  @type t :: %{
          name: String.t(),
          nickname: String.t(),
          private_key: nil | String.t(),
          color: nil | String.t(),
          socket_pid: pid(),
          rooms: MapSet.t()
        }

  @nickname_word_list_1 [
    "Robot",
    "Bio",
    "Doctor",
    "Puzzle",
    "Automata",
    "Buzz",
    "Data",
    "Buzz",
    "Zap",
    "Infinity",
    "Cyborg",
    "Android",
    "Electro",
    "Robo",
    "Battery",
    "Beep",
    "Chip",
    "Boron",
    "Zat",
    "Gort",
    "Torg",
    "Plex",
    "Doom",
    "Mecha",
    "Alpha",
    "Beta",
    "Gamma",
    "Proto",
    "R2"
  ]

  @nickname_word_list_2 [
    "HAL",
    "Lover",
    "Love",
    "Power",
    "nic",
    "Servo",
    "Clicker",
    "Friend",
    "Zap",
    "Zip",
    "Zapper",
    "Genius",
    "Beep",
    "Boop",
    "Sim",
    "Asimov",
    "Talos",
    "EVE",
    "-3PO",
    "Rossum",
    "bot"
  ]

  @nickname_word_list_3 [
    "69",
    "420",
    "XxX",
    "2001",
    "borg",
    "9000",
    "100",
    "2020",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    ""
  ]

  @colors [
    "#707070",
    "#e05e5e",
    "#e09f5e",
    "#e0e05e",
    "#9fe05e",
    "#5ee05e",
    "#5ee09f",
    "#5ee0e0",
    "#5e9fe0",
    "#5e5ee0",
    "#9f5ee0",
    "#e05ee0",
    "#e05e9f",
    "#b19278",
    "#e0e0e0"
  ]

  def start_link(%{player_name: player_name, socket_pid: socket_pid, private_key: private_key} = opts) do   
    {:ok, _} = GenServer.start_link(__MODULE__, opts, name: {:via, Registry, {Registry.PlayerRegistry, player_name, private_key}})
  end

  @impl true
  @spec init(%{player_name: String.t(), socket_pid: pid(), private_key: String.t()}) :: {:ok, %__MODULE__{}}
  def init(%{player_name: player_name, socket_pid: socket_pid, private_key: private_key} = opts) do
    
    # Register the private key with this player name & PID.
    Registry.register(Registry.PlayerRegistry, private_key, player_name)

    state = %__MODULE__{
      name: player_name,
      nickname: player_name,
      private_key: private_key,
      color: generate_color(),
      socket_pid: socket_pid
    }

    Logger.info("Created new player #{inspect(opts)}. There are now #{inspect (Registry.count(Registry.PlayerRegistry)/2)} players.")

    {:ok, state}
  end

  @spec new(pid(), String.t()) :: String.t()
  def new(socket_pid, private_key) do
    player_name = generate_name()

    Logger.debug("Attempting to create player with name \"#{player_name}\".")
    PlayerSupervisor.start_child(%{player_name: player_name, socket_pid: socket_pid, private_key: private_key})

    player_name
  end

  @spec fetch(String.t()) :: {:ok, __MODULE__.t()} | :error
  def fetch(player_name) do
    # Logger.debug("The PlayerRegister has: #{inspect(Registry.count(Registry.PlayerRegistry))} players.")
    
    case GenServer.whereis(via_tuple(player_name)) do
      nil -> :error

      _proc -> 
        case GenServer.call(via_tuple(player_name), :get_state) do
          {:ok, player} -> {:ok, player}
          _ -> :error
        end
      end
  end


  # @spec update(String.t(), ) :: String.t()
  def update(player_name, new_info) do
    
    # {:ok, player} = Player.fetch(player_name)

    GenServer.call(via_tuple(player_name), {:update_player, new_info})
  end
  

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:update_player, new_info}, _from, state) do
   
    new_username =
      if String.trim(new_info["nickname"]) != "" do
        String.slice(String.trim(new_info["nickname"]), 0, 16)
      else
        state.nickname
      end
  
    new_color =
      if String.trim(new_info["color"]) != "" do
        String.trim(new_info["color"])
      else
        state.color
      end

    state = %{ state | nickname: new_username, color: new_color }

    {:reply, {:ok, state}, state}
  end

  defp via_tuple(player_name) do
    {:via, Registry, {Registry.PlayerRegistry, player_name}}
  end
  

  # Return a new nickname. We generate a nickname by combining 3 words from 3
  # word lists.
  @spec generate_name() :: String.t()
  defp generate_name() do
    player_name =
      Enum.random(@nickname_word_list_1) <>
        Enum.random(@nickname_word_list_2) <> Enum.random(@nickname_word_list_3)

    case Registry.lookup(Registry.PlayerRegistry, player_name) do
      {:ok, _} -> generate_name()
      [] -> player_name
    end
  end

  
  # Returns a JSON encodable map.
 # @spec to_map(__MODULE__.t()) :: %{username: String.t(), color: String.t(), score: int, is_admin: bool, is_muted: bool}
  def to_map(player, team, score, is_admin, is_muted) do
    %{ username: player.name, nickname: player.nickname, team: team, color: player.color, score: score, is_admin: is_admin, is_muted: is_muted }
  end


  # Return a random color from a defined list.
  @spec generate_color() :: String.t()
  defp generate_color() do
    Enum.random(@colors)
  end
end

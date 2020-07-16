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
            color: "#c6c6c6",
            socket_pid: nil,
            rooms: MapSet.new()

  @type t :: %{
          name: String.t(),
          nickname: String.t(),
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

  def start_link(opts) do
    
    Logger.debug("In Player.start_link with #{inspect(opts.player_name)}")
    
    player_name = Map.get(opts, :player_name, "PLAYANAME")

    {:ok, _} = GenServer.start_link(__MODULE__, opts, name: via_tuple(player_name))

  end

  @impl true
  @spec init(%{player_name: String.t(), socket_pid: pid()}) :: {:ok, %__MODULE__{}}
  def init(%{player_name: player_name, socket_pid: socket_pid} = opts) do
    
    state = %__MODULE__{
      name: player_name,
      color: generate_color(),
      socket_pid: socket_pid
    }

    Logger.info("Created new player #{inspect(opts)}.")
    Logger.debug("There are now: #{inspect(Registry.count(Registry.PlayerRegistry))} players.")

    {:ok, state}
  end

  @spec new(pid()) :: String.t()
  def new(socket_pid) do
    player_name = generate_name()

    Logger.debug("Attempting to create player with name \"#{player_name}\".")
    PlayerSupervisor.start_link(%{player_name: player_name, socket_pid: socket_pid})

    player_name
  end

  @spec fetch(String.t()) :: {:ok, __MODULE__.t()} | :error
  def fetch(player_name) do
    Logger.debug("The PlayerRegister has: #{inspect(Registry.count(Registry.PlayerRegistry))} players.")
    
    case GenServer.whereis(via_tuple(player_name)) do
      nil -> :error

      proc -> 
        case GenServer.call(via_tuple(player_name), :get_state) do
          {:ok, player} -> {:ok, player}
          _ -> :error
        end
      end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  defp via_tuple(player_name) do
    {:via, Registry, {Registry.PlayerRegistry, player_name}}
    # {:via, Registry.PlayerRegistry, {:player_name, player_name}}
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
  def to_map(player, score, is_admin, is_muted) do
    %{ username: player.name, color: player.color, score: score, is_admin: is_admin, is_muted: is_muted }
  end


  # Return a random color from a defined list.
  @spec generate_color() :: String.t()
  defp generate_color() do
    Enum.random(@colors)
  end
end

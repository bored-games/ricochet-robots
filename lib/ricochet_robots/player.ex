defmodule RicochetRobots.Player do
  @moduledoc """
  A `Player` is a user, including any relevant settings or information.

  `color` is a "#rrggbb" string.
  `room` is the name of the room they are in.
  """

  defstruct name: nil,
            color: "#c6c6c6",
            rooms: MapSet.new()

  @type t :: %{
          name: String.t(),
          color: nil | String.t(),
          rooms: MapSet.t()
        }

  def new() do
    player_name = Player.generate_nickname()

    Logger.debug("Attempting to create player with name \"#{player_name}\".")
    PlayerSupervisor.start_link(%{player_name: player_name})

    player_name
  end

  def start_link(%{player_name: player_name} = opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(player_name))
  end

  @impl true
  @spec init(%{player_name: String.t()})
  def init(%{player_name: player_name} = opts) do
    Logger.info("Started new player.")

    state = %__MODULE__{
      name: player_name,
      color: generate_color()
    }

    {:ok, state}
  end

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
    "2020"
  ]

  @doc """
  Return a new nickname. We generate a nickname by combining 3 words from 3
  word lists.
  """
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

  @doc """
  Return a random color from a defined list.
  """
  @spec generate_color() :: String.t()
  defp generate_color() do
    Enum.random(@colors)
  end
end

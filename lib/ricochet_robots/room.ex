defmodule RicochetRobots.Room do
  use Genserver

  # TODO: IDs & Registry?

  defstruct [
    id: nil,
    name: nil,
    game: nil,
    players: [],
    chat: [],
  ]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl true
  def init({name: name}) do
    {:ok, %Room{id: 1, name: name}}
  end

  def create_game({name: name}) do
    handle_cast({:create_game, name)}
  end

  def add_player({player: player}) do
    handle_cast({:add_player, player})
  end

  def send_message({player: player, message: message}) do
    handle_cast({:send_message, {player, message}})
  end

  @impl true
  def handle_cast({:create_game, name}, state) do
    game = RicochetRobots.Game.start_link()
    {:ok, Map.put(state, :game, game)}
  end

  @impl true
  def handle_cast({:add_player, player}, state) do
    state.players = [ player | state.players ]
    {:ok, state}
  end

  @impl true
  def handle_cast({:send_message, {player, message}) do
    state.chat = [ message | state.chat ]
    {:ok, state}
  end
end

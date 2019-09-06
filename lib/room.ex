defmodule Room do
  use Genserver

  # TODO: IDs & Registry?
  # TODO: Dynamic supervisor for rooms.

  defstruct [
    id: nil,
    name: nil,
    game: nil,
    players: [],
    chat: [],
  ]

  def init({name: name, player: player}) do
    {:ok, %Room{id: 1, name: name, player: {player}}}
  end

  def handle_cast({}, state) do
    {}
  end

  def handle_call({}, state) do
    {}
  end
end

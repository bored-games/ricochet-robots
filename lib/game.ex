defmodule Game do
  use GenServer

  defstruct [
    board: nil,
    robots: nil,
    idk_help: nil,
  ]

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast({}, state) do
    {}
  end

  def handle_call({}, state) do
    {}
  end
end

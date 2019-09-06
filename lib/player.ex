defmodule Player do
  use GenServer

  defstruct [
    nickname: nil,
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

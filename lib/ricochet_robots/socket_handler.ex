defmodule RicochetRobots.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger

  def init(request, _state) do
    state = %{registry_key: request.path}
    {:cowboy_websocket, request, state}
  end

  # Terminate if no activity for one minute--client should be sending pings.
  @timeout 60000

  def websocket_init(state) do
    Registry.RicochetRobots
    |> Registry.register(state.registry_key, {})

    {:ok, state}
  end

  def websocket_handle({:text, "ping"}, state) do
    Logger.debug("received ping")
    {:reply, {:text, "pong"}, state}
  end

  def websocket_handle({:text, message}, state) do
    Logger.debug("received: #{message}")
    {:ok, state}
  end

  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end
end

defmodule RicochetRobots.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger

  def init(request, _state) do
    state = %{registry_key: request.path}
    {:cowboy_websocket, request, state}
  end

  # Terminate if no activity for one minute--client should be sending pings.
  @timeout 90000

  def websocket_init(state) do
    Registry.RicochetRobots
    |> Registry.register(state.registry_key, {})

    {:ok, state}
  end

  def websocket_handle({:text, "ping"}, state) do
    Logger.debug("ping pong")
    {:reply, {:text, "pong"}, state}
  end

  def websocket_handle({:text, message}, state) do
    data = Poison.decode!(message)
    websocket_handle({:json, message}, state)
    {:ok, state}
  end

  def websocket_handle({:json, %{"action": "create_room"} = data, state) do
    # Create a room, create the player, add player to state.
    # Create and log to chat.
  end

  def websocket_handle({:json, %{"action": "join_room"} = data, state) do
    # Create the player, have it join the room, add player to state.
    # Max # of players per game check?
    # Log to chat.
  end

  def websocket_handle({:json, %{"action": "new_game"} = data, state) do
    # Create the board and randomize the setup; modify game state.
    # Log to chat.
  end

  def websocket_handle({:json, %{"action": "submit_solution"} = data, state) do
    # Check solution with solver
    # Log submission and result to chat.
  end

  def websocket_handle({:json, %{"action": "send_chat_message"} = data, state) do
    # Relay to chat.
  end

  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end
end

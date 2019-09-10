defmodule RicochetRobots.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger

  @impl true
  def init(request, _state) do
    state = %{registry_key: request.path, player: %Player{}}
    {:cowboy_websocket, request, state}
  end

  # Terminate if no activity for one minute--client should be sending pings.
  @timeout 90000

  @impl true
  def websocket_init(state) do
    Registry.RicochetRobots
    |> Registry.register(state.registry_key, {})

    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, "ping"}, state) do
    Logger.debug("ping pong")
    {:reply, {:text, "pong"}, state}
  end

  @impl true
  def websocket_handle({:set_nick, nick}, state) do
    state.player = Map.put(state.player, :nickname, nick)
    {:reply, {:text "success"}, state}
  end

  @impl true
  def websocket_handle({:text, message}, state) do
    data = Poison.decode!(message)
    websocket_handle({:json, message}, state)
    {:ok, state}
  end

  @impl true
  def websocket_handle({:json, %{"action": "create_room"} = data, state) do
    # Create a room, create the player, add player to state.
    # Create and log to chat.
  end

  @impl true
  def websocket_handle({:json, %{"action": "join_room"} = data, state) do
    # Create the player, have it join the room, add player to state.
    # Max # of players per game check?
    # Log to chat.
  end

  @impl true
  def websocket_handle({:json, %{"action": "new_game"} = data, state) do
    # Create the board and randomize the setup; modify game state.
    # Log to chat.
  end

  @impl true
  def websocket_handle({:json, %{"action": "submit_solution"} = data, state) do
    # Check solution with solver
    # Log submission and result to chat.
  end

  @impl true
  def websocket_handle({:json, %{"action": "send_chat_message"} = data, state) do
    # Relay to chat.
  end

  @impl true
  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end
end

defmodule Player do
  defstruct nickname: nil
end

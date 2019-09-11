defmodule RicochetRobots.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger

  @impl true
  def init(request, _state) do
    state = %{registry_key: request.path, player: %Player{}}
    {:cowboy_websocket, request, state}
  end

  # Terminate if no activity for 1.5 minutes--client should be sending pings.
  @timeout 90000

  @impl true
  def websocket_init(state) do
    Registry.RicochetRobots
    |> Registry.register(state.registry_key, {})

    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, message}, state) do
    data = Poison.decode!(message)
    websocket_handle({:json, message}, state)
    {:ok, state}
  end

  @impl true
  def websocket_handle({:json, {"action": "ping"}, state) do
    Logger.debug("ping pong")
    {:reply, {:text, "pong"}, state}
  end

  @impl true
  def websocket_handle({:json, {"action": "set_nick", "nick": nick}, state) do
    state.player = Map.put(state.player, :nickname, nick)
    {:reply, {:text "success"}, state}
  end

  @impl true
  def websocket_handle({:json, %{"action": "create_room", "name": name}, state) do
    RicochetRobots.RoomSupervisor.start_link(name)
    RicochetRobots.Room.log_to_chat("Created room.")
  end

  @impl true
  def websocket_handle({:json, %{"action": "join_room"}, state) do
    # Create the player, have it join the room, add player to state.
    # Max # of players per game check?
    # Log to chat.
  end

  @impl true
  def websocket_handle({:json, %{"action": "new_game"}, state) do
    # Create the board and randomize the setup; modify game state.
    # Log to chat.
  end

  @impl true
  def websocket_handle({:json, %{"action": "submit_solution", "solution": solution}, state) do
    # Check solution with solver
    # Log submission and result to chat.
  end

  @impl true
  def websocket_handle({:json, %{"action": "send_chat_message", "message": message}, state) do
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

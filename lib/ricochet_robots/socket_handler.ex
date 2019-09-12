defmodule RicochetRobots.SocketHandler do
  @behaviour :cowboy_websocket

  require Logger

  @impl true
  def init(request, _state) do
    state = %{
      registry_key: request.path,
      player: %RicochetRobots.Player{name: RicochetRobots.Player.generate_name()}
    }

    {:cowboy_websocket, request, state}
  end

  # Terminate if no activity for 1.5 minutes--client should be sending pings.
  @idle_timeout 90000

  @impl true
  def websocket_init(state) do
    Registry.RicochetRobots
    |> Registry.register(state.registry_key, {})

    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, message}, state) do
    data = Poison.decode!(message)
    websocket_handle({:json, data}, state)
    {:ok, state}
  end

  @impl true
  def websocket_handle({:json, %{action: "ping"}}, state) do
    Logger.debug("ping pong")
    {:reply, {:text, "pong"}, state}
  end

  @impl true
  def websocket_handle({:json, %{action: "create_room", name: name}}, state) do
    RoomSupervisor.start_link(name)
    Room.log_to_chat("Created room.")
    {:reply, {:text, "success"}, state}
  end

  @impl true
  def websocket_handle({:json, %{action: "join_room"}}, state) do
    # Create the player, have it join the room, add player to state.
    # Max # of players per game check?
    Room.log_to_chat(state.player.name <> " joined the room.")
    {:reply, {:text, "success"}, state}
  end

  @impl true
  def websocket_handle({:json, %{action: "new_game"}}, state) do
    Room.new_game()
    Room.log_to_chat("New game started by #{state.player.name}.")
    {:reply, {:text, "success"}, state}
  end

  @impl true
  def websocket_handle({:json, %{action: "submit_solution", solution: solution}}, state) do
    Game.submit_solution(solution)
    Room.log_to_chat("Solution submitted by #{state.player.name}")
    {:reply, {:text, "success"}, state}
  end

  @impl true
  def websocket_handle({:json, %{action: "send_chat_message", message: message}}, state) do
    Room.send_message(state.player, message)
    {:reply, {:text, "success"}, state}
  end

  @impl true
  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end
end

defmodule Gameboy.SocketHandler do
  @moduledoc """
  Controls the way a user interacts with a `Room` (e.g. chat) or a `Game` (e.g.
  making a move).

  The state for a socket handler is the unique player name.
  """

  require Logger
  alias Gameboy.{Player, Room}
  alias Gameboy.RicochetRobots.Main, as: RicochetRobots

  defstruct player_name: nil

  @type t :: %{
          player_name: String.t(),
        }

  @behaviour :cowboy_websocket
  @idle_timeout 90_000

  @doc """
  The first thing to happen for a new websocket connection.
  """
  @impl true
  def init(request, state) do
    Logger.info("New websocket connection initiated.")
    {:cowboy_websocket, request, state, %{idle_timeout: @idle_timeout}}
  end

  @doc """
  Happens after init()
  """
  @impl true
  def websocket_init(_state) do
    
    state = %__MODULE__{
      player_name: Player.new(self())
    }

    {:ok, state}
  end

  @doc """
  Take a websocket transmission and attempt to decode the JSON. If the
  transmission is valid, match the transmission against other more specific
  handlers. If invalid, return an error to the client.
  """
  @impl true
  def websocket_handle({:text, json}, state) do

    case Poison.decode(json) do
      {:ok, payload} ->
        websocket_handle({:json, payload["action"], payload["content"]}, state)

      {:error, _} ->
        Logger.info("Failed to decode JSON transmission from \"#{state.player_name}\".")
        {:reply, {:text, "Failed to decode JSON."}, state}

    end
  end



  @doc """
  Action: ping

  The client should periodically ping the server if no other transmissions have
  been sent over the socket. If no transmissions have been sent in the last 90
  seconds, the server will assume that the client has timed out and the socket
  will be closed. We respond with a pong.
  """
  @impl true
  def websocket_handle({:json, "ping", _content}, state) do
    response = Poison.encode!(%{action: "ping", content: "pong"})
    {:reply, {:text, response}, state}
  end

  @doc """
  Action: create_room

  Players can create new rooms, the name of which will be autogenerated. They
  will be made the admin of the room and joined to the room.

  Options:
    player_limit: The player limit for the new room. By default, 8.
  """
  @impl true
  def websocket_handle({:json, "create_room", content}, state) do
    # room_name = Room.new(opts)
    Logger.debug("websocket_handle create_room with #{content}")
    room_name = Room.new( %{room_name: content} )
    
    Room.add_player(room_name, state.player_name)

    {:reply, {:text, "Room created..."}, state}
  end

  @doc """
  Action: join_room

  Join an existing room if the room is not over the player limit. New player
  will need to wait to the start of the next game to play, but they will be
  able to participate in chat.
  """
  @impl true
  def websocket_handle({:json, "join_room", room_name}, state) do
    case Room.add_player(room_name, state.player_name) do
      :ok -> 
        Registry.register(Registry.RoomPlayerRegistry, room_name, state.player_name)
        Room.welcome_player(room_name, state.player_name)

        response = Poison.encode!(%{action: "connect_to_server", content: room_name})
        {:reply, {:text, response}, state}

      :error ->
        
        {:reply, {:text, "[join_room] Failure"}, state}
    end
  end



  @doc """
  Action: new_game

  Start a new game. Check to see if a game is currently in progress; if one
  is, then do not do anything. If no game is currently in progress, send out a
  new board, new robots, and new goals to players.
  # TODO: Enforce who can start a new game? Or log who started the game?
  """
  @impl true
  def websocket_handle({:json, "new_game", %{room_name: _room_name}}, state) do
    Logger.debug("[New game] remove log msg when it's working.")


    {:reply, {:text, "failure"}, state}
    # case Game.fetch(room_name) do
    #   {:ok, _game} ->
    #     Game.new_round(room_name)
    #     {:reply, {:text, "success"}, state}

    #   :error ->
    #     case Game.new(room_name) do
    #       :ok ->
    #         Room.system_chat(room_name, "#{state.player.username} has started a new game!")
    #         {:reply, {:text, "success"}, state}

    #       :error ->
    #         {:reply, {:text, "failure"}, state}
    #     end
    # end
  end

  #what the heck is this for now
  @doc "get_user : need to send out user initialization info to client, and new user message, scoreboard to all users"
  @impl true
  def websocket_handle({:json, "get_user", room_name}, state) do
    {:ok, user_map} = Room.get_player(room_name, state.player_name)
    
    response = Poison.encode!(%{action: "update_user", content: user_map})
    {:reply, {:text, response}, state}
  end

  
  @doc """
  ping: Built in ????
  """
  @impl true
  def websocket_handle({:ping, msg}, state) do
    # Logger.debug("[PING] from #{inspect state}")
    {:reply, {:pong, msg}, state}
  end



  @doc """
  TODO: New chatline: need to send out new chatline to all users
  """
  @impl true
  def websocket_handle({:json, "update_chat", content}, state) do
    Logger.debug("[Room chat] remove log msg when it's working.")

    #To do: update chat probably needs to take the room name as an argument, and later, check if the user is even in the room. 
   #  {:ok, player} = Player.fetch(state.player_name)
    
    
    #unless player.is_muted do
      Room.player_chat(content["room_name"], state.player_name, content["message"])
    #end

    {:reply, {:text, "success"}, state}
  end

  # TODO: Validate name against other users! Move to player.ex!
  @doc "update_user : need to send validated user info to 1 client and new scoreboard to all"
  @impl true
  def websocket_handle({:json, "update_user", content}, state) do
    Logger.debug("[Update Player] #{state.player_name} --> #{inspect content}")

    Player.update(state.player_name, content)

    # send scoreboard to all
    Room.broadcast_scoreboard("Default Room")

    # send client their new user info
    {:ok, player} = Player.fetch(state.player_name)    
    user_map = Player.to_map(player, 0, false, false)
    
    response = Poison.encode!(%{content: user_map, action: "update_user"})
    {:reply, {:text, response}, state}
  end

  # TODO: all
  @doc "submit_movelist : simulate the req. moves"
  @impl true
  def websocket_handle({:json, "submit_movelist", content}, state) do
    Logger.debug("[Move] " <> state.player_name <> " --> #{inspect content}")
    new_robots = RicochetRobots.move_robots("Default Room", state.player_name, content)
    response = Poison.encode!(%{content: new_robots, action: "update_robots"})
    {:reply, {:text, response}, state}
  end

  @doc "_ : handle all other JSON data with `action` as unknown."
  @impl true
  def websocket_handle({:json, action, _}, state) do
    Logger.debug("Unhandled action from client #{state.player_name}: " <> action)

    response = Poison.encode!(%{action: "error", content: "Unsupported action."})
    {:reply, {:text, response}, state}
  end

  @doc """
  Forward Elixir messages to client.
  """
  @impl true
  def websocket_info({:send_json, json}, state) do
    {:reply, {:text, json}, state}
  end


  @impl true
  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end

  # TODO: all
  @doc """
  Callback function for a terminated socket. Announce the player's
  parting, remove them from all their rooms, and broadcast the state change to
  all clients.
  """
  @impl true
  def terminate(reason, _req, state) do
    Logger.debug("Termination #{inspect(reason)} -  #{inspect(state)}")
    Room.system_chat("Default Room", state.player_name <> " has left.")
    Room.remove_player("Default Room", state.player_name)
    Room.broadcast_scoreboard("Default Room")
    :ok
  end
end

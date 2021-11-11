defmodule Gameboy.SocketHandler do
  @moduledoc """
  Controls the way a user interacts with a `Room` (e.g. chat) or a `Game` (e.g.
  making a move).

  The state for a socket handler is the unique player name.
  """

  require Logger
  alias Gameboy.{Player, Room}

  defstruct player_name: nil,
            room_name: nil

  @type t :: %{
      player_name: String.t(),
      room_name: String.t(),
        }

  @behaviour :cowboy_websocket
  @idle_timeout 90_000

  @doc """
  The first thing to happen for a new websocket connection.
  """
  @impl true
  def init(request, _state) do
    state = %__MODULE__{
      player_name: Player.new(self(), request.headers["sec-websocket-protocol"]),
      room_name: nil
    }

    case request.path_info do
      [ "robots" | [room_name]] ->
        Logger.info("New websocket connection (robots > #{room_name}) initiated.")
        state = %{state | room_name: room_name } # TO DO: verify that this is the right place to add this. can it be added in add_player?
        {:cowboy_websocket, request, {room_name, "Ricochet Robots", state}, %{idle_timeout: @idle_timeout}}
      [ "canoe" | [room_name]] ->
        Logger.info("New websocket connection (canoe > #{room_name}) initiated.")
        state = %{state | room_name: room_name } # TO DO: verify that this is the right place to add this. can it be added in add_player?
        {:cowboy_websocket, request, {room_name, "Canoe", state}, %{idle_timeout: @idle_timeout}}
      [ "codenames" | [room_name]] ->
        Logger.info("New websocket connection (codenames > #{room_name}) initiated.")
        state = %{state | room_name: room_name } # TO DO: verify that this is the right place to add this. can it be added in add_player?
        {:cowboy_websocket, request, {room_name, "Codenames", state}, %{idle_timeout: @idle_timeout}}
      [ "homeworlds" | [room_name]] ->
        Logger.info("New websocket connection (homeworlds > #{room_name}) initiated.")
        state = %{state | room_name: room_name } # TO DO: verify that this is the right place to add this. can it be added in add_player?
        {:cowboy_websocket, request, {room_name, "Homeworlds", state}, %{idle_timeout: @idle_timeout}}
      _ ->
        Logger.info("New websocket connection (lobby) initiated.")
        {:cowboy_websocket, request, state, %{idle_timeout: @idle_timeout}}
    end


  end

  # TO DO: If a player joins a room but is expecting a different game.. problem.
  # Happens after init()
  @impl true
  def websocket_init({room_name, game_name, state}) do

    send(self(), get_player(state.player_name))


    case websocket_handle({:json, "join_room", room_name}, state) do
      {:reply, {:text, reply}, _state} -> send(self(), reply)
      :error_nonexistant_room ->
        case websocket_handle({:json, "create_room", %{room_name: room_name, game_name: game_name}}, state) do
          {:reply, {:text, _reply}, _state} ->
            case websocket_handle({:json, "join_room", room_name}, state) do
              {:reply, {:text, reply}, _state} -> send(self(), reply)
              error -> Logger.debug("Unhandled error after creating room: #{inspect error}")
            end
        end
      error -> Logger.debug("Unhandled error: #{inspect error}")
    end
    
    {:ok, state}
  end

  @doc """
  Happens after init() if there was no requested room
  """
  @impl true
  def websocket_init(state) do
    send(self(), get_player(state.player_name))
    {:ok, state}
  end


  
  @doc """
  Return the player's info as JSON... TO DO: INCLUDE SCORE, ETC
  """
  def get_player(player_name) do
    case Player.fetch(player_name) do
      {:ok, player} -> Poison.encode!(%{action: "update_user", content: Player.to_map(player, 0, 0, false, false) })
      error -> Logger.info("get_player error: #{inspect error}")
    end
  end



  # Take a websocket transmission and attempt to decode the JSON. If the transmission is valid, match the transmission against other more specific handlers. If invalid, return an error to the client.
  @impl true
  def websocket_handle({:text, json}, state) do
    case Poison.decode(json) do
      {:ok, payload} ->
        case websocket_handle({:json, payload["action"], payload["content"]}, state) do
          {:reply, response, state} -> {:reply, response, state}
          :error_nonexistant_room -> {:reply, {:text, "Failure: room does not exist"}, state}
          :error_max_players -> {:reply, {:text, "Failure: room is at maximum player count"}, state}
          :error_finding_player -> {:reply, {:text, "Failure: error adding/finding player"}, state}
        end
      {:error, _} ->
        Logger.info("Failed to decode JSON transmission #{inspect json} from #{inspect state}.")
        {:reply, {:text, "Failed to decode JSON."}, state}
    end
  end



  # The client should periodically ping the server if no other transmissions have been sent over the socket.
  # If no transmissions have been sent in the last 90 seconds, the server will assume that the client has timed out and the socket will be closed. We respond with a pong.
  @impl true
  def websocket_handle({:json, "ping", _content}, state) do
    response = Poison.encode!(%{action: "ping", content: "pong"})
    {:reply, {:text, response}, state}
  end


  #  TO DO!
  @impl true
  def websocket_handle({:json, "create_room", opts}, state) do # %{ room_name: room_name, game_name: game_name }
    Logger.debug("websocket_handle create_room with #{inspect opts}")
    {room_name, game_name} = Room.new(opts |> Map.new(fn {k, v} -> if is_atom(k) do {k, v} else {String.to_atom(k), v} end end))
    Logger.debug("CREATE ROOM: #{inspect(room_name)} #{inspect(game_name)}")

    url =
      case game_name do
        "Canoe" -> "./canoe/?room=" <> room_name
        "Codenames" -> "./codenames/?room=" <> room_name
        "Homeworlds" -> "./homeworlds/?room=" <> room_name
        "Ricochet Robots" -> "./robots/?room=" <> room_name
        _ -> "./lobby/?room=" <> room_name
      end

    response = Poison.encode!(%{action: "redirect", content: url})
    {:reply, {:text, response}, state}
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

      error -> error
    end
  end



  # Start a new game. Check to see if a game is currently in progress; if one is, then do not do anything. If no game is currently in progress...
  # TODO: Enforce who can start a new game. Only an admin...
  @impl true
  def websocket_handle({:json, "new_game", %{room_name: _room_name}}, state) do
    Logger.debug("[New game] To do; remove log msg when it's working.")

    {:reply, {:text, "failure"}, state}
  end

  # get_rooms : need to send out user initialization info to client, and new user message, scoreboard to all users
  @impl true
  def websocket_handle({:json, "get_rooms", _}, state) do
    {:ok, rooms} = Room.get_rooms()
    response = Poison.encode!(%{action: "update_rooms", content: rooms})
    {:reply, {:text, response}, state}
  end
  

  # "get_user : need to send out user initialization info to client, and new user message, scoreboard to all users"
  @impl true
  def websocket_handle({:json, "get_user", room_name}, state) do
    {:ok, user_map} = Room.get_player(room_name, state.player_name)
    
    response = Poison.encode!(%{action: "update_user", content: user_map})
    {:reply, {:text, response}, state}
  end

  
  # ping: Built in ????
  @impl true
  def websocket_handle({:ping, msg}, state) do
    {:reply, {:pong, msg}, state}
  end



  #  New chatline: need to send out new chatline to all users
  @impl true
  def websocket_handle({:json, "update_chat", content}, state) do

    #To do: update chat probably needs to take the room name as an argument, and later, check if the user is even in the room. 
   #  {:ok, player} = Player.fetch(state.player_name)
    
    #TODO unless player.is_muted do
      Room.player_chat(state.room_name, state.player_name, content["message"])
    #end

    {:reply, {:text, "success"}, state}
  end

  # TODO: Validate name against other users! Move to player.ex!
  # "update_user : need to send validated user info to 1 client and new scoreboard to all"
  @impl true
  def websocket_handle({:json, "update_user", content}, state) do
    Logger.debug("[Update Player] #{state.player_name} --> #{inspect content}")

    Player.update(state.player_name, content)

    # send scoreboard to all
    Room.broadcast_scoreboard(state.room_name)

    # send client their new user info: TO DO: team, score, isadmin, ismuted
    {:ok, player} = Player.fetch(state.player_name)    
    user_map = Player.to_map(player, 0, 0, false, false)
    
    response = Poison.encode!(%{content: user_map, action: "update_user"})
    {:reply, {:text, response}, state}
  end

  

  # Handle arbitrary `game_action` calls. If a game exists, the content of the call is passed on to the game, and the response is sent back to the client.
  # - submit_movelist : simulate a set of Ricochet Robots moves
  @impl true
  def websocket_handle({:json, "game_action", content}, state) do
    # Logger.debug("[WS Game Info] " <> state.player_name <> " --> #{inspect content}")

    response =
      case Room.fetch(state.room_name) do
        {:ok, room} ->
          case Room.get_game_module(room.game) do
            :error_no_current_game ->
              "Error: no current game in room"
            :error_unknown_game ->
              "Error: unknown game"
            game_module -> game_module.handle_game_action(content["action"], content["content"], state)
          end
        :error -> "No room found"
      end

    response = if is_atom(response) do
      Logger.debug("To do: clean up websocket game_action (#{inspect response} from #{inspect content})")
      "#{inspect response}"
    else
      response
    end

    {:reply, {:text, response}, state}
  end

  # "_ : handle all other JSON data with `action` as unknown."
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
  Callback function for a terminated socket. Announce the player's parting, remove them from all their rooms, and broadcast the state change to all clients.
  """
  @impl true
  def terminate(reason, _req, state) do
    Logger.debug("Termination #{inspect(reason)} -  #{inspect(state)}")
    Room.system_chat(state.room_name, state.player_name <> " has left.")
    Room.remove_player(state.room_name, state.player_name)
    Room.broadcast_scoreboard(state.room_name)
    :ok
  end
end

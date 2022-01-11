defmodule Gameboy.PyWorker do
  @moduledoc false
  use GenServer
  use Export.Python
  require Logger

  # optional, omit if adding this to a supervision tree
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def canoe_ai(reds, blues, ai_team) do
    Logger.debug("Calling canoe_ai (#{__MODULE__})")
    GenServer.call(__MODULE__, {:canoe_ai, {reds, blues, ai_team}}, 15000)
  end
  
  def init_canoe_ai() do
    GenServer.call(__MODULE__, {:init_canoe_ai}, 15000)
  end

  # server
  def init(state) do
    priv_path = Path.join(:code.priv_dir(:gameboy), "python")
    {:ok, py} = Python.start_link(python_path: priv_path)
    state = Map.put(state, :py, py)
    Logger.debug("Initialized Python.}")
    {:ok, state}
  end

  def handle_call({:init_canoe_ai}, _from, %{py: py} = state) do
    raw = Python.call(py, "canoe_ai", "init", [])
    {:reply, raw, state}
  end

  def handle_call({:canoe_ai, {reds, blues, ai_team}}, _from, %{py: py} = state) do
    raw = Python.call(py, "canoe_ai", "canoe_ai", [reds, blues, ai_team])
    {:reply, raw, state}
  end

  def terminate(_reason, %{py: py} = _state) do
    Python.stop(py)
    :ok
  end
end
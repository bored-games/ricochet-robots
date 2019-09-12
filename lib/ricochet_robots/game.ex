defmodule RicochetRobots.Game do
  use GenServer

  defstruct board: nil

  def start_link() do
    GenServer.start_link(__MODULE__, [], __MODULE__)
  end

  @impl true
  def init(_) do
    board =
      create_board()
      |> populate_board()

    {:ok, %__MODULE__{board: board}}
  end

  def create_board() do
    # Board elements: nil, :robot, :vertical_wall, :horizontal_wall ?

    board = %{}

    for x <- 0..32 do
      for y <- 0..32 do
        board = Map.put(board, {x, y}, nil)
      end
    end

    board
  end

  def populate_board(board) do
    # Randomly populate board with elements (represented as atoms?).
    board
  end

  def check_solution(board, solution) do
    GenServer.cast(__MODULE__, {:check_solution, solution})
  end

  @impl true
  def handle_cast({:check_solution, solution}, state) do
    # Solve it and broadcast results to sockets.
    {:noreply, state}
  end
end

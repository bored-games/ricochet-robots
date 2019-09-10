defmodule RicochetRobots.Game do
  use GenServer

  defstruct [
    board: nil,
  ]

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  @impl true
  def init(_) do
    board = create_board()
            |> populate_board()

    {:ok, %Game{board: board}}
  end

  def create_board(rows, columns) do
    # Board elements: nil, :robot, :vertical_wall, :horizontal_wall ?

    board = %Board{}
    for i <- 0..(rows - 1), do
      board.board = Map.put(board.board, i, %{})
      for j <- 0..(columns - 1), do
        board.board[i] = Map.put(board.board[i], j, :nil)
      end
    end

    board
  end

  def populate_board(board) do
    # Randomly populate board with elements (represented as atoms?).
    board
  end

  def check_solution(board, solution) do
    # Pass to handle_call? IDK!
    true
  end
end

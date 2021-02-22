defmodule Gameboy.RicochetRobots.Puzzle do
  use Ecto.Schema

  schema "ricochet_puzzles" do
      field :boundary_board, :string
      field :red_pos, :integer
      field :yellow_pos, :integer
      field :green_pos, :integer
      field :blue_pos, :integer
      field :silver_pos, :integer
      field :goal_color, :string
      field :goal_pos, :integer
      field :solution_str, :string
      field :solution_robots, :integer
      field :solution_moves, :integer
      field :difficulty, :integer
      field :is_posted, :boolean
      field :posted_at, :naive_datetime
      field :is_image, :boolean
      field :is_uploaded, :boolean
      field :upload_id, :string
      field :post_id, :string
      timestamps()
  end

  def changeset(puzzle, params \\ %{}) do
    puzzle
    |> Ecto.Changeset.cast(params, [:boundary_board, :red_pos, :yellow_pos, :green_pos, :blue_pos, :silver_pos, :goal_color, :goal_pos, :solution_str, :solution_robots, :solution_moves, :difficulty])
    |> Ecto.Changeset.validate_required([:boundary_board, :red_pos, :yellow_pos, :green_pos, :blue_pos, :silver_pos, :goal_color, :goal_pos, :solution_str, :solution_robots, :solution_moves, :difficulty])
  end

end
defmodule Gameboy.RicochetRobots.Repo.Migrations.CreateRicochetPuzzles do
  use Ecto.Migration

  def change do
    create table(:ricochet_puzzles) do
      add :boundary_board, :text
      add :red_pos, :integer
      add :yellow_pos, :integer
      add :green_pos, :integer
      add :blue_pos, :integer
      add :silver_pos, :integer
      add :goal_color, :string
      add :goal_pos, :integer
      add :solution_str, :string
      add :solution_robots, :integer
      add :solution_moves, :integer
      add :difficulty, :integer, default: 0
      add :is_image, :boolean, default: false
      add :imgur_soln_url, :string
      add :imgur_hide_url, :string
      add :imgur_soln_deletehash, :string
      add :imgur_hide_deletehash, :string
      add :is_posted, :boolean, default: false
      add :posted_at, :naive_datetime
      add :post_id, :string
      timestamps()
    end


  end
end

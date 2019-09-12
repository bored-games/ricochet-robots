defmodule RicochetRobots.Player do
  defstruct nickname: nil,
            score: 0,
            is_admin: false

  def generate_name() do
    # Make it extremely unlikely for nicknames to collide...
    # have a few million permutations please!
    "RobotLover420"
  end

  def add_to_score(player, delta) do
    %__MODULE__{player | score: Map.get(player, :score) + delta}
  end
end

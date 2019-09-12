defmodule RicochetRobots.Player do
  defstruct nickname: nil,
            score: 0,
            is_admin: false

  def add_to_score(player, delta) do
    %__MODULE__{player | score: Map.get(player, :score) + delta}
  end
end

defmodule RicochetRobots.Player do
  defstruct username: nil,
            color: "#c6c6c6",
            score: 0,
            is_admin: false,
            is_muted: false,
            joined: nil

  # TODO: take list of previous names and verify unique?
  @doc "Return a new user with unique, randomized name"
  def generate_username() do
    # Make it extremely unlikely for nicknames to collide...
    # have a few million permutations please!
    arr1 = ["Robot", "Doctor", "Puzzle", "Automaton", "Data", "Buzz", "Infinity", "Cyborg", "Android", "Electro", "Robo", "Battery", "Beep" ];
    arr2 = ["Lover", "Love", "Power", "Clicker", "Friend", "Genius", "Beep", "Boop", "Sim", "Asimov", "Talos" ];
    arr3 = ["69", "420", "XxX", "2001", "", "", "", "", "", "", "", "", ""];
    username = Enum.random(arr1) <> Enum.random(arr2) <> Enum.random(arr3)
  #  color = Enum.random(["#707070", "#e05e5e", "#e09f5e", "#e0e05e", "#9fe05e", "#5ee05e", "#5ee09f", "#5ee0e0", "#5e9fe0", "#5e5ee0", "#9f5ee0", "#e05ee0", "#e05e9f", "#b19278", "#e0e0e0"])
    username

  end

  def add_to_score(player, delta) do
    %__MODULE__{player | score: Map.get(player, :score) + delta}
  end
end

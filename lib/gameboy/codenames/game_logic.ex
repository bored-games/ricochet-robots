defmodule Gameboy.Codenames.GameLogic do
  @moduledoc """
  This module contains functions that handle game logic.
  """

  require Logger
  use Bitwise
  alias Gameboy.Codenames.{Main}
  alias Gameboy.Codenames.{Wordlists}


  @doc """
  Simply put a peg in the correct hole
  """
  @spec make_move([Main.card_t], integer, integer) :: :error_not_valid_move | {boolean, boolean, integer, integer, [Main.card_t]}
  def make_move(board, teamid, index) do
    case Enum.find(board, fn c -> c.id == index end ) do
      nil -> :error_not_valid_move
      target ->
        continue_turn = teamid == target.team
        assassin = target.team == -1
        board = Enum.map(board, fn c -> if c.id == index do %{c | uncovered: true} else c end end)
        red_remaining = Enum.count(board, fn c -> c.team == 1 and c.uncovered == false end)
        blue_remaining = Enum.count(board, fn c -> c.team == 2 and c.uncovered == false end)
        {continue_turn, assassin, red_remaining, blue_remaining, board}
    end
  end
  

 

  @doc """
  Return a randomized boundary board, its visual map, and corresponding goal positions.
  """
  @spec populate_board() :: {String.t(), [Main.card_t()], integer, integer, integer}
  def populate_board() do

    current_team = :rand.uniform(2)
    red_remaining = 10 - current_team
    blue_remaining = 7 + current_team

    all_words = Wordlists.basic_words
    words = Enum.take_random(all_words, 25)
    ids = Enum.shuffle(0..24)
    
    cards = Enum.zip(ids, words)


    {[{assassin_id, assassin_word}], cards} = Enum.split(cards, 1)
    {red_cards, cards} = Enum.split(cards, red_remaining)
    {blue_cards, specator_cards} = Enum.split(cards, blue_remaining)

    code = (2-current_team) <<< 52
    code = code ||| (0b11 <<< (2*assassin_id))
    code = Enum.reduce(red_cards, code, fn {i, w}, c -> c ||| (0b01 <<< (2*i)) end)
    code = Enum.reduce(blue_cards, code, fn {i, w}, c -> c ||| (0b10 <<< (2*i)) end)
    prime = 0b1010110011110100001100011110100001011000010000101011
    password = Integer.to_string(prime ^^^ code, 36)

    board = [%{id: assassin_id, word: assassin_word, team: -1, uncovered: false}]
    board = board ++ for {i, w} <- red_cards, do: %{id: i, word: w, team: 1, uncovered: false}
    board = board ++ for {i, w} <- blue_cards, do: %{id: i, word: w, team: 2, uncovered: false}
    board = board ++ for {i, w} <- specator_cards, do: %{id: i, word: w, team: 0, uncovered: false}
    board = Enum.sort_by(board, fn %{id: i} -> i end)


    {password, board, red_remaining, blue_remaining, current_team}

  end
end


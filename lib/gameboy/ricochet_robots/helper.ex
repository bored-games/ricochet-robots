defmodule Gameboy.RicochetRobots.Helper do
  @moduledoc """
  This module contains functions that handle basic math and conversions.
  """

  @doc """
  Convert position tuple from 16x16 board to {15, 14} to 254, etc.
  """
  @spec pos_tuple_to_uint({integer, integer}) :: integer
  def pos_tuple_to_uint({x, y}) do
    16*y + x
  end

  @spec pos_tuple_to_uint(%{x: integer, y: integer}) :: integer
  def pos_tuple_to_uint(%{x: x, y: y}) do
    16*y + x
  end

end
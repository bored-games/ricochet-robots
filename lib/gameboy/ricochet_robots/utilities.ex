defmodule Gameboy.RicochetRobots.Utilities do
  @moduledoc """
  This module contains functions that handle basic math and conversions.
  """

  @doc """
  Convert position tuple from 16x16 board to {15, 14} to 254, etc.
  """
  # TODO  @spec symbol_to_color_string(String.t()) :: String.t()
  def cell_index_to_map(idx) do
    %{x: rem(idx, 16), y: div(idx, 16)}
  end
  
  # TODO  @spec symbol_to_color_string(String.t()) :: String.t()
  def cell_map_to_index(%{x: x, y: y}) do
    16*y + x
  end


end
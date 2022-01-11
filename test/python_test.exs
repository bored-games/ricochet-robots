defmodule Gameboy.PyWorkerTest do
  use ExUnit.Case, async: true
  # alias Gameboy.PyWorker

  test "starts up a python process" do
    assert {:ok, %{py: pid}} = Gameboy.PyWorker.init(%{})
    assert pid
  end
  
  test "duplicate/1 performs duplication of text" do 
    # Python code always returns charlists instead of strings
    assert 'texttext' = Gameboy.PyWorker.duplicate("text")
  end
end

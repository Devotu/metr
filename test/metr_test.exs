defmodule MetrTest do
  use ExUnit.Case

  test "list players" do
    assert is_list Metr.list_players()
  end

  test "list decks" do
    assert is_list Metr.list_decks()
  end
end

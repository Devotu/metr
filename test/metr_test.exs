defmodule MetrTest do
  use ExUnit.Case

  test "list players" do
    IO.inspect(Metr.list_players(), label: "metr test - resulting list")
    assert is_list Metr.list_players()
  end
end

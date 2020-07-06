defmodule PlayerTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event
  alias Metr.Player


  test "basic feed" do
    assert [] == Player.feed Event.new([:show, :game], %{id: "abc_efg"})
  end


  test "create player" do
    [resulting_event] = Player.feed Event.new([:create, :player], %{name: "Testy"})
    assert [:player, :created] == resulting_event.tags
    Data.wipe_state("Player", resulting_event.data.id)
  end
end

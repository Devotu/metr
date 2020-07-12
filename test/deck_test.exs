defmodule DeckTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Deck
  alias Metr.Event
  alias Metr.Player


  test "basic feed" do
    assert [] == Deck.feed Event.new([:not, :relevant], %{id: "abc_123"})
  end


  test "create deck" do
    Player.feed Event.new([:create, :player], %{name: "Decky"})
    [resulting_event] = Deck.feed Event.new([:create, :deck], %{name: "Create deck", player_id: "decky", colors: [:black, :red]})
    assert [:deck, :created] == resulting_event.tags
    Data.wipe_state("Deck", resulting_event.data.id)
    Data.wipe_state("Player", resulting_event.data.player_id)
  end


  test "fail create deck" do
    [resulting_event] = Deck.feed Event.new([:create, :deck], %{name: "Fail create deck", player_id: "faily"})
    assert [:deck, :create, :fail] == resulting_event.tags
  end
end

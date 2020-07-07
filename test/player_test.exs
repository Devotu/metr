defmodule PlayerTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event
  alias Metr.Player


  test "basic feed" do
    assert [] == Player.feed Event.new([:not, :relevant], %{id: "abc_123"})
  end


  test "create player" do
    [resulting_event] = Player.feed Event.new([:create, :player], %{name: "Testy"})
    assert [:player, :created] == resulting_event.tags
    Data.wipe_state("Player", resulting_event.data.id)
  end


  test "deck created" do
    #var
    player_id = "deck_owner"
    deck_name = "Player deck"
    deck_id = "player_deck"
    #Player to own the deck
    [player_created_event] = Player.feed Event.new([:create, :player], %{name: "Deck owner"})
    #Resolve deck created
    [resulting_event] = Player.feed Event.new([:deck, :created], %{id: deck_id, player_id: player_id})
    #Assert
    resulting_feedback_should_be = "Deck #{deck_id} added to player #{player_id}"
    assert [:player, :altered] == resulting_event.tags
    assert resulting_feedback_should_be == resulting_event.data.msg
    #Cleanup
    # Data.wipe_state("Player", player_created_event.data.id)
  end
end

defmodule PlayerTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event
  alias Metr.Game
  alias Metr.Id
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
    Data.wipe_state("Player", player_created_event.data.id)
  end


  test "game created" do
    #var
    #Players to participate
    player_one_name = "Filip"
    player_one_id = Id.hrid(player_one_name)
    Player.feed Event.new([:create, :player], %{name: player_one_name})
    player_two_name = "Gustav"
    player_two_id = Id.hrid(player_two_name)
    Player.feed Event.new([:create, :player], %{name: player_two_name})
    #Resolve game created

    [game_created_event] = Game.feed Event.new([:create, :game], %{
          parts: [
            %{details: %{deck_id: "festering", force: 2, fun: -1, player_id: player_one_id}, part: 1},
            %{details: %{deck_id: "gloom", force: 1, fun: 2, player_id: player_two_id}, part: 2}
          ],
          winner: 2
        })

    resulting_events = Player.feed(game_created_event)
    first_resulting_event = List.first(resulting_events)

    #Assert
    assert 2 == Enum.count(resulting_events)
    assert [:player, :altered] == first_resulting_event.tags
    assert "Game #{game_created_event.data.id} added to player #{player_one_id}" == first_resulting_event.data.msg
    #Cleanup
    Data.wipe_state("Player", player_one_id)
    Data.wipe_state("Player", player_two_id)
    Data.wipe_state("Game", game_created_event.data.id)
  end
end

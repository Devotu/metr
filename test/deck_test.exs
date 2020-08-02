defmodule DeckTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Deck
  alias Metr.Event
  alias Metr.Game
  alias Metr.Id
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


  test "deck created" do
    #var
    #Players to participate
    player_one_name = "Helge"
    player_one_id = Id.hrid(player_one_name)
    Player.feed Event.new([:create, :player], %{name: player_one_name})
    player_two_name = "Ivar"
    player_two_id = Id.hrid(player_two_name)
    Player.feed Event.new([:create, :player], %{name: player_two_name})
    #Decks to participate
    deck_one_name = "Haste"
    deck_one_id = Id.hrid(deck_one_name)
    Deck.feed Event.new([:create, :deck], %{name: deck_one_name, player_id: player_one_id})
    deck_two_name = "Imprint"
    deck_two_id = Id.hrid(deck_two_name)
    Deck.feed Event.new([:create, :deck], %{name: deck_two_name, player_id: player_two_id})
    #Resolve game created

    [game_created_event] = Game.feed Event.new([:create, :game], %{
          parts: [
            %{details: %{deck_id: deck_one_id, power: -1, fun: -2, player_id: player_one_id}, part: 1},
            %{details: %{deck_id: deck_two_id, power: 1, fun: 2, player_id: player_two_id}, part: 2}
          ],
          winner: 1
        })

    resulting_events = Deck.feed(game_created_event)
    first_resulting_event = List.first(resulting_events)

    #Assert
    assert 2 == Enum.count(resulting_events)
    assert [:deck, :altered] == first_resulting_event.tags
    assert "Game #{game_created_event.data.id} added to deck #{deck_one_id}" == first_resulting_event.data.msg
    #Cleanup
    Data.wipe_state("Player", player_one_id)
    Data.wipe_state("Player", player_two_id)
    Data.wipe_state("Deck", deck_one_id)
    Data.wipe_state("Deck", deck_two_id)
    Data.wipe_state("Game", game_created_event.data.id)
  end
end

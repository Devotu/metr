defmodule DeckTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Deck
  alias Metr.Event
  alias Metr.Game
  alias Metr.Id
  alias Metr.Player


  test "basic feed" do
    assert [] == Deck.feed Event.new([:not, :relevant], %{id: "abc_123"}), nil
  end


  test "create deck" do
    Player.feed Event.new([:create, :player], %{name: "Decky"}), nil
    [resulting_event] = Deck.feed Event.new([:create, :deck], %{name: "Create deck", player_id: "decky", colors: [:black, :red]}), nil
    assert [:deck, :created, nil] == resulting_event.tags
    Data.wipe_state("Deck", resulting_event.data.id)
    Data.wipe_state("Player", resulting_event.data.player_id)
  end


  test "fail create deck" do
    [resulting_event] = Deck.feed Event.new([:create, :deck], %{name: "Fail create deck", player_id: "faily"}), nil
    assert [:deck, :create, :fail] == resulting_event.tags
  end


  test "deck created" do
    #var
    #Players to participate
    player_1_name = "Helge"
    player_1_id = Id.hrid(player_1_name)
    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    player_2_name = "Ivar"
    player_2_id = Id.hrid(player_2_name)
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    #Decks to participate
    deck_1_name = "Haste"
    deck_1_id = Id.hrid(deck_1_name)
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    deck_2_name = "Imprint"
    deck_2_id = Id.hrid(deck_2_name)
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil
    #Resolve game created

    [game_created_event] = Game.feed Event.new([:create, :game], %{
          parts: [
            %{details: %{deck_id: deck_1_id, power: -1, fun: -2, player_id: player_1_id}, part: 1},
            %{details: %{deck_id: deck_2_id, power: 1, fun: 2, player_id: player_2_id}, part: 2}
          ],
          winner: 1,
          rank: false
        }), nil

    resulting_events = Deck.feed game_created_event, nil
    first_resulting_event = List.first(resulting_events)

    #Assert
    assert 2 == Enum.count(resulting_events)
    assert [:deck, :altered] == first_resulting_event.tags
    assert "Game #{game_created_event.data.id} added to deck #{deck_1_id}" == first_resulting_event.data.out
    #Cleanup
    Data.wipe_state("Player", [player_1_id, player_2_id])
    Data.wipe_state("Deck", [deck_1_id, deck_2_id])
    Data.wipe_state("Game", [game_created_event.data.id])
  end


  test "alter rank" do
    player_1_name = "Adam Deck"
    player_1_id = Id.hrid(player_1_name)
    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    deck_1_name = "Alpha Deck"
    deck_1_id = Id.hrid(deck_1_name)
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil

    [deck_1_1] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck_1_1.data.out.rank == nil

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id}), nil
    [deck_1_2] = Deck.feed Event.new([:read, :deck], %{change: 1, deck_id: deck_1_id}), nil
    assert deck_1_2.data.out.rank == 1

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id}), nil
    [deck_1_3] = Deck.feed Event.new([:read, :deck], %{change: 1, deck_id: deck_1_id}), nil
    assert deck_1_3.data.out.rank == 1

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id}), nil
    [deck_1_3] = Deck.feed Event.new([:read, :deck], %{change: 1, deck_id: deck_1_id}), nil
    assert deck_1_3.data.out.rank == 2

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id}), nil
    [deck_1_3] = Deck.feed Event.new([:read, :deck], %{change: -1, deck_id: deck_1_id}), nil
    assert deck_1_3.data.out.rank == 1

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id}), nil
    [deck_1_3] = Deck.feed Event.new([:read, :deck], %{change: 1, deck_id: deck_1_id}), nil
    assert deck_1_3.data.out.rank == 2

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id}), nil
    [deck_1_3] = Deck.feed Event.new([:read, :deck], %{change: 1, deck_id: deck_1_id}), nil
    assert deck_1_3.data.out.rank == 2

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id}), nil
    [deck_1_3] = Deck.feed Event.new([:read, :deck], %{change: 1, deck_id: deck_1_id}), nil
    assert deck_1_3.data.out.rank == 2

    Data.wipe_state("Deck", player_1_id)
    Data.wipe_state("Player", deck_1_id)
  end
end

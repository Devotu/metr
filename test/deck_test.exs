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
    Data.wipe_test("Deck", resulting_event.data.id)
    Data.wipe_test("Player", resulting_event.data.player_id)
  end


  test "fail create deck" do
    [resulting_event] = Deck.feed Event.new([:create, :deck], %{name: "Fail create deck", player_id: "faily"}), nil
    assert [:deck, :create, :fail] == resulting_event.tags
  end


  test "create deck with format" do
    Player.feed Event.new([:create, :player], %{name: "Ceasar Deck"}), nil
    format = "pauper"
    [create_event] = Deck.feed Event.new([:create, :deck], %{name: "Charlie Deck", player_id: "ceasar_deck", colors: [:green, :blue], format: format}), nil
    assert [:deck, :created, nil] == create_event.tags
    deck_id = create_event.data.id
    [read_event] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_id}), nil
    deck = read_event.data.out
    assert format == deck.format
    Data.wipe_test("Deck", deck_id)
    Data.wipe_test("Player", create_event.data.player_id)
  end


  test "create deck with colors" do
    Player.feed Event.new([:create, :player], %{name: "Erik Deck"}), nil
    [create_event] = Deck.feed Event.new([:create, :deck], %{name: "Echo Deck", player_id: "erik_deck", colors: [:red, :blue]}), nil
    assert [:deck, :created, nil] == create_event.tags
    deck_id = create_event.data.id
    [read_event] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_id}), nil
    deck = read_event.data.out
    assert false == deck.black
    assert false == deck.white
    assert true == deck.red
    assert false == deck.green
    assert true == deck.blue
    assert false == deck.colorless
    Data.wipe_test("Deck", deck_id)
    Data.wipe_test("Player", create_event.data.player_id)
  end


  test "create deck with failed format" do
    Player.feed Event.new([:create, :player], %{name: "David Deck"}), nil
    format = "failingformat"
    [create_event] = Deck.feed Event.new([:create, :deck], %{name: "Delta Deck", player_id: "david_deck", colors: [:green, :blue], format: format}), nil
    assert [:deck, :not, :created, nil] == create_event.tags
    assert [:invalid_format] == create_event.data.errors
    Data.wipe_test("Player", "david_deck")
  end


  test "deck created" do
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
    deck_log = Data.read_log_by_id("Deck", deck_1_id)

    #Assert
    assert 2 == Enum.count(resulting_events)
    assert [:deck, :altered] == first_resulting_event.tags
    assert "Game #{game_created_event.data.id} added to deck #{deck_1_id}" == first_resulting_event.data.out
    assert 2 == Enum.count(deck_log)

    #Cleanup
    Data.wipe_test("Player", [player_1_id, player_2_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id])
    Data.wipe_test("Game", [game_created_event.data.id])
  end


  test "alter rank" do
    player_1_name = "Adam Deck"
    player_1_id = Id.hrid(player_1_name)
    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    deck_1_name = "Alpha Deck"
    deck_1_id = Id.hrid(deck_1_name)
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil

    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id, change: 1}), nil
    assert deck.data.out.rank == nil

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: 1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {0,1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: 1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {1,0}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: 1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {1,1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: 1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {2,0}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {2,-1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: 1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {2,0}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: 1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {2,1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: 1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {2,1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {2,0}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {2,-1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {1,0}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {1,-1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {0,0}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {0,-1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {-1,0}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {-1,-1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {-2,0}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {-2,-1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: -1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {-2,-1}

    Deck.feed Event.new([:rank, :altered], %{deck_id: deck_1_id, change: 1}), nil
    [deck] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id}), nil
    assert deck.data.out.rank == {-2,0}

    Data.wipe_test("Deck", deck_1_id)
    Data.wipe_test("Player", player_1_id)
  end


  test "create game with specified rank" do
    player_1_name = "Bertil Deck"
    player_1_id = Id.hrid(player_1_name)
    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    deck_1_name = "Bravo Deck"
    deck_1_id = Id.hrid(deck_1_name)
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id, rank: {1,-1}}), nil

    [deck_1] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_1_id, change: 1}), nil
    assert deck_1.data.out.rank == {1,-1}

    Data.wipe_test("Deck", deck_1_id)
    Data.wipe_test("Player", player_1_id)
  end
end

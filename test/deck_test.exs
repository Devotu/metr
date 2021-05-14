defmodule DeckTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Modules.Deck
  alias Metr.Event
  alias Metr.Modules.Game
  alias Metr.Id
  alias Metr.Modules.Player
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput

  test "basic feed" do
    assert [] == Deck.feed(Event.new([:not, :relevant], %{id: "abc_123"}), nil)
  end

  test "create deck" do
    Player.feed(Event.new([:create, :player], %{name: "Decky"}), nil)

    [resulting_event] =
      Deck.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "Create deck",
          player_id: "decky",
          black: true,
          red: true,
          format: "standard"
        }),
        nil
      )

    assert [:deck, :created, nil] == resulting_event.keys
    Data.wipe_test("Deck", resulting_event.data.id)
    Data.wipe_test("Player", resulting_event.data.player_id)
  end

  test "fail create deck" do
    player_id = "faily"
    name = "Fail create deck"

    [resulting_event] =
      Deck.feed(Event.new([:create, :deck], %DeckInput{name: name, player_id: player_id, format: "standard"}), "repp")

    assert [:deck, :error, "repp"] == resulting_event.keys
    assert "player faily not found" == resulting_event.data.cause
  end

  test "create deck with format" do
    Player.feed(Event.new([:create, :player], %{name: "Ceasar Deck"}), nil)
    format = "pauper"

    [create_event] =
      Deck.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "Charlie Deck",
          player_id: "ceasar_deck",
          green: true,
          blue: true,
          format: format
        }),
        nil
      )

    assert [:deck, :created, nil] == create_event.keys
    deck_id = create_event.data.id
    [read_event] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    deck = read_event.data.out
    assert format == deck.format
    Data.wipe_test("Deck", deck_id)
    Data.wipe_test("Player", create_event.data.player_id)
  end

  test "create deck with colors" do
    Player.feed(Event.new([:create, :player], %{name: "Erik Deck"}), nil)

    [create_event] =
      Deck.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "Echo Deck",
          player_id: "erik_deck",
          red: true,
          blue: true,
          format: "standard"
        }),
        nil
      )

    assert [:deck, :created, nil] == create_event.keys
    deck_id = create_event.data.id
    [read_event] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
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
    Player.feed(Event.new([:create, :player], %{name: "David Deck"}), nil)
    format = "failingformat"

    [create_event] =
      Deck.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "Delta Deck",
          player_id: "david_deck",
          green: true,
          blue: true,
          format: format
        }),
        nil
      )

    assert [:deck, :error, nil] == create_event.keys
    assert "format failingformat not vaild" == create_event.data.cause
    Data.wipe_test("Player", "david_deck")
  end

  test "deck created" do
    # Players to participate
    player_1_name = "Helge"
    player_1_id = Id.hrid(player_1_name)
    Player.feed(Event.new([:create, :player], %{name: player_1_name}), nil)
    player_2_name = "Ivar"
    player_2_id = Id.hrid(player_2_name)
    Player.feed(Event.new([:create, :player], %{name: player_2_name}), nil)
    # Decks to participate
    deck_1_name = "Haste"
    deck_1_id = Id.hrid(deck_1_name)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_1_name, player_id: player_1_id, format: "standard"}), nil)
    deck_2_name = "Imprint"
    deck_2_id = Id.hrid(deck_2_name)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_2_name, player_id: player_2_id, format: "standard"}), nil)
    # Resolve game created

    [game_created_event] =
      Game.feed(
        Event.new([:create, :game], %GameInput{
          player_one: player_1_id,
          player_two: player_2_id,
          deck_one: deck_1_id,
          deck_two: deck_2_id,
          power_one: -1,
          power_two: 1,
          fun_one: -2,
          fun_two: 2,
          winner: 1,
          ranking: false
        }),
        nil
      )

    resulting_events = Deck.feed(game_created_event, nil)
    first_resulting_event = List.first(resulting_events)
    deck_log = Data.read_log_by_id(deck_1_id, "Deck")
    [first_result_id, _second_result_event] = game_created_event.data.result_ids

    # Assert
    assert 2 == Enum.count(resulting_events)
    assert [:deck, :altered, nil] == first_resulting_event.keys

    assert "Result #{first_result_id} added to deck #{deck_1_id}" ==
             first_resulting_event.data.out

    assert 2 == Enum.count(deck_log)

    # Cleanup
    Data.wipe_test("Player", [player_1_id, player_2_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id])
    Data.wipe_test("Game", [game_created_event.data.id])
    Data.wipe_test("Result", game_created_event.data.result_ids)
  end

  test "alter rank" do
    player_1_name = "Adam Deck"
    player_1_id = Id.hrid(player_1_name)
    Player.feed(Event.new([:create, :player], %{name: player_1_name}), nil)
    deck_1_name = "Alpha Deck"
    deck_1_id = Id.hrid(deck_1_name)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_1_name, player_id: player_1_id, format: "standard"}), nil)

    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id, change: 1}), nil)
    assert deck.data.out.rank == nil

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {0, 1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {1, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {1, 1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {2, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {2, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {2, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {2, 1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {2, 1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {2, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {2, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {1, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {1, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {0, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {0, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {-1, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {-1, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {-2, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {-2, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {-2, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_1_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_1_id}), nil)
    assert deck.data.out.rank == {-2, 0}

    Data.wipe_test("Deck", deck_1_id)
    Data.wipe_test("Player", player_1_id)
  end

  test "create minimum deck" do
    player_name = "Gustav Deck"
    player_id = Id.hrid(player_name)
    Player.feed(Event.new([:create, :player], %{name: player_name}), nil)
    deck_name = "Golf Deck"
    format = "block"

    [resulting_event] =
      Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_name, player_id: player_id, format: format}), nil)

    assert [:deck, :created, nil] == resulting_event.keys

    deck = Deck.read(resulting_event.data.id)
    assert format == deck.format
    assert "" == deck.theme
    assert nil == deck.rank
    assert nil == deck.price
    assert [] == deck.matches
    assert [] == deck.results
    assert false == deck.black
    assert false == deck.white
    assert false == deck.red
    assert false == deck.green
    assert false == deck.blue
    assert false == deck.colorless

    Data.wipe_test("Deck", resulting_event.data.id)
    Data.wipe_test("Player", player_id)
  end

  test "toggle deck active" do
    player_name = "Helge Deck"
    player_id = Id.hrid(player_name)
    Player.feed(Event.new([:create, :player], %{name: player_name}), nil)
    deck_name = "Hotel Deck"

    [resulting_event] =
      Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_name, player_id: player_id, format: "standard"}), nil)

    deck_id = resulting_event.data.id
    created_deck = Deck.read(deck_id)
    assert true == created_deck.active

    Deck.feed(Event.new([:toggle, :deck, :active], %{deck_id: deck_id}), nil)
    toggled_deck = Deck.read(deck_id)
    assert false == toggled_deck.active

    Deck.feed(Event.new([:toggle, :deck, :active], %{deck_id: deck_id}), nil)
    reverted_deck = Deck.read(deck_id)
    assert true == reverted_deck.active

    Data.wipe_test("Deck", deck_id)
    Data.wipe_test("Player", player_id)
  end

  test "result order" do
    player_name = "Ivar Deck"
    deck_name = "India Deck"
    player_two_name = "Johan Deck"
    deck_two_name = "Juliet Deck"

    {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id} =
      TestHelper.init_double_state(player_name, deck_name, player_two_name, deck_two_name)

    original_deck = Deck.read(deck_one_id)
    [first_result_id] = original_deck.results

    create_game_data = %GameInput{
      deck_one: deck_one_id,
      deck_two: deck_two_id,
      player_one: player_one_id,
      player_two: player_two_id,
      winner: 1
    }

    second_game_id = Metr.create(create_game_data, :game)

    updated_deck = Deck.read(deck_one_id)
    [^first_result_id, second_result_id] = updated_deck.results

    third_game_id = Metr.create(create_game_data, :game)

    updated_deck = Deck.read(deck_one_id)
    [^first_result_id, ^second_result_id, _third_result_id] = updated_deck.results

    player_one = Metr.read(player_one_id, :player)
    player_two = Metr.read(player_two_id, :player)

    Data.wipe_test("Game", [second_game_id, third_game_id])
    Data.wipe_test("Result", player_one.results)
    Data.wipe_test("Result", player_two.results)
    TestHelper.cleanup_double_states(
      {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id}
    )
  end
end

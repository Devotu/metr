defmodule DeckTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Modules.Deck
  alias Metr.Event
  alias Metr.Modules.Game
  alias Metr.Id
  alias Metr.Modules.State
  alias Metr.Modules.Player
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.PlayerInput

  test "basic feed" do
    assert [] == Deck.feed(Event.new([:not, :relevant], %{id: "abc_123"}), nil)
  end

  test "create deck" do
    player_id = TestHelper.init_only_player "Adam Deck"

    deck_id =
      State.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "Create deck",
          player_id: player_id,
          black: true,
          red: true,
          format: "standard"
        }),
        nil
      )
    |> List.first()
    |> Event.get_out()

    TestHelper.wipe_test(:deck, deck_id)
    TestHelper.wipe_test(:player, player_id)
  end

  test "fail create deck" do
    player_id = "faily"
    name = "Fail create deck"

    [creation_event] =
      State.feed(Event.new([:create, :deck], %DeckInput{name: name, player_id: player_id, format: "standard"}), nil)

    assert [:error, nil] == creation_event.keys
    assert "player faily not found" == creation_event.data.cause
  end

  test "create deck with format" do
    player_id = TestHelper.init_only_player "Bertil Deck"
    format = "pauper"

    created_event = State.feed(
      Event.new([:create, :deck], %DeckInput{
        name:  "Charlie Deck",
        player_id: player_id,
        green: true,
        blue: true,
        format: format
      }),
      nil
    )
    |> List.first()


    assert [:deck, :created, nil] == created_event.keys
    deck_id = created_event.data.out
    [read_event] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    deck = read_event.data.out
    assert format == deck.format
    TestHelper.wipe_test(:deck, deck_id)
    TestHelper.wipe_test(:player, player_id)
  end

  test "create deck with colors" do
    player_id = TestHelper.init_only_player "Erik Deck"

    created_event =
      State.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "Echo Deck",
          player_id: player_id,
          red: true,
          blue: true,
          format: "standard"
        }),
        nil
      )
      |> List.first()

    assert [:deck, :created, nil] == created_event.keys
    deck_id = created_event.data.out
    [read_event] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    deck = read_event.data.out
    assert false == deck.black
    assert false == deck.white
    assert true == deck.red
    assert false == deck.green
    assert true == deck.blue
    assert false == deck.colorless
    TestHelper.wipe_test(:deck, deck_id)
    TestHelper.wipe_test(:player, player_id)
  end

  test "create deck with failed format" do
    player_id = TestHelper.init_only_player "David Deck"
    format = "failingformat"

    created_event =
      State.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "Delta Deck",
          player_id: player_id,
          green: true,
          blue: true,
          format: format
        }),
        nil
      )
      |> List.first()

    assert [:error, nil] == created_event.keys
    assert "format failingformat not vaild" == created_event.data.cause
    TestHelper.wipe_test(:player, "david_deck")
  end

  test "alter rank" do
    player_id = TestHelper.init_only_player "Adam Deck"
    deck_id = TestHelper.init_only_deck "Alpha Deck", player_id

    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id, change: 1}), nil)
    assert deck.data.out.rank == nil

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {0, 1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {1, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {1, 1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {2, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {2, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {2, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {2, 1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {2, 1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {2, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {2, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {1, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {1, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {0, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {0, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {-1, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {-1, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {-2, 0}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {-2, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: -1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {-2, -1}

    Deck.feed(Event.new([:alter, :rank], %{deck_id: deck_id, change: 1}), nil)
    [deck] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    assert deck.data.out.rank == {-2, 0}

    TestHelper.wipe_test(:deck, deck_id)
    TestHelper.wipe_test(:player, player_id)
  end

  test "create minimum deck" do
    player_id = TestHelper.init_only_player "Gustav Deck"
    deck_name = "Golf Deck"
    format = "block"

    creation_event =
      State.feed(Event.new(
        [:create, :deck],
        %DeckInput{
          name: deck_name,
          player_id: player_id,
          format: format}
        ),
        nil)
        |> List.first()

    assert [:deck, :created, nil] == creation_event.keys

    deck = Deck.read(creation_event.data.out)
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

    TestHelper.wipe_test(:deck, creation_event.data.out)
    TestHelper.wipe_test(:player, player_id)
  end

  test "toggle deck active" do
    player_id = TestHelper.init_only_player "Helge Deck"
    deck_id = TestHelper.init_only_deck "Hotel Deck", player_id

    created_deck = Deck.read(deck_id)
    assert true == created_deck.active

    Deck.feed(Event.new([:toggle, :deck, :active], %{deck_id: deck_id}), nil)
    toggled_deck = Deck.read(deck_id)
    assert false == toggled_deck.active

    Deck.feed(Event.new([:toggle, :deck, :active], %{deck_id: deck_id}), nil)
    reverted_deck = Deck.read(deck_id)
    assert true == reverted_deck.active

    TestHelper.wipe_test(:deck, deck_id)
    TestHelper.wipe_test(:player, player_id)
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

    TestHelper.wipe_test(:game, [second_game_id, third_game_id])
    TestHelper.wipe_test(:result, player_one.results)
    TestHelper.wipe_test(:result, player_two.results)
    TestHelper.cleanup_double_states(
      {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id}
    )
  end


  test "create deck failed name" do
    player_id = TestHelper.init_only_player "Kalle Deck"

    [creation_event] =
      State.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "",
          player_id: player_id,
          black: true,
          red: true,
          format: "standard"
        }),
        nil
      )

    assert [:error, nil] == creation_event.keys

    [creation_event] =
      State.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  nil,
          player_id: nil,
          black: true,
          red: true,
          format: "standard"
        }),
        nil
      )

    assert [:error, nil] == creation_event.keys

    [creation_event] =
      State.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "a name with more than 32 codepoints",
          player_id: nil,
          black: true,
          red: true,
          format: "standard"
        }),
        nil
      )

    assert [:error, nil] == creation_event.keys

    TestHelper.wipe_test(:player, player_id)
  end

  test "create deck failed format" do
    player_name = "Kalle Deck"
    player_id = Id.hrid(player_name)
    State.feed(Event.new([:create, :player], %PlayerInput{name: player_name}), nil)

    [creation_event] =
      State.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "",
          player_id: player_id,
          black: true,
          red: true,
          format: "not something we have"
        }),
        nil
      )

    assert [:error, nil] == creation_event.keys
    TestHelper.wipe_test(:player, player_id)
  end

  test "create deck failed player" do
    [creation_event] =
      State.feed(
        Event.new([:create, :deck], %DeckInput{
          name:  "",
          player_id: nil,
          black: true,
          red: true,
          format: "standard"
        }),
        nil
      )

    assert [:error, nil] == creation_event.keys
  end
end

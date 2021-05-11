defmodule MatchTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Modules.Deck
  alias Metr.Modules.Match
  alias Metr.Event
  alias Metr.Modules.Player
  alias Metr.Modules.Stately
  alias Metr.Router
  alias Metr.Modules.Input.DeckInput

  test "basic feed" do
    assert [] == Match.feed(Event.new([:not, :relevant], %{id: "abc_123"}), nil)
  end

  test "create match" do
    [player_created_event] =
      Player.feed(Event.new([:create, :player], %{name: "Adam Match"}), nil)

    player_id = player_created_event.data.out

    [deck_created_event] =
      Deck.feed(Event.new([:create, :deck], %DeckInput{name: "Alpha Match", player_id: player_id, format: "standard"}), nil)

    deck_id = deck_created_event.data.id

    Router.input(
      Event.new([:create, :match], %{
        player_1_id: player_id,
        deck_1_id: deck_id,
        player_2_id: player_id,
        deck_2_id: deck_id,
        ranking: false
      })
    )

    [read_deck_event] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    deck = read_deck_event.data.out
    assert 2 == Enum.count(deck.matches)

    [read_player_event] = Stately.feed(Event.new([:read, :player], %{player_id: player_id}), nil)
    player = read_player_event.data.out
    assert 2 == Enum.count(player.matches)

    match_id = List.first(deck.matches)
    [read_match_event] = Match.feed(Event.new([:read, :match], %{match_id: match_id}), nil)
    match = read_match_event.data.out
    assert :initialized == match.status
    assert false == match.ranking
    assert deck_id == match.deck_one

    Data.wipe_test("Match", match_id)
    Data.wipe_test("Player", player_id)
    Data.wipe_test("Deck", deck_id)
  end

  test "fail create match" do
    [player_created_event] =
      Player.feed(Event.new([:create, :player], %{name: "Bertil Match"}), nil)

    player_id = player_created_event.data.out

    [deck_1_created_event] =
      Deck.feed(Event.new([:create, :deck], %DeckInput{name: "Bravo Match", player_id: player_id, format: "standard"}), nil)

    deck_id_1 = deck_1_created_event.data.id

    [deck_2_created_event] =
      Deck.feed(
        Event.new([:create, :deck], %DeckInput{name: "Charlie Match", player_id: player_id, format: "standard"}),
        nil
      )

    deck_id_2 = deck_2_created_event.data.id

    Metr.alter_rank(deck_id_2, :up)
    Metr.alter_rank(deck_id_2, :up)

    [resulting_event] =
      Match.feed(
        Event.new([:create, :match], %{
          player_1_id: player_id,
          deck_1_id: deck_id_1,
          player_2_id: player_id,
          deck_2_id: deck_id_2,
          ranking: true
        }),
        nil
      )

    assert [:match, :error, nil] == resulting_event.keys
    assert "ranks does not match" == resulting_event.data.cause
    Data.wipe_test("Player", player_id)
    Data.wipe_test("Deck", [deck_id_1, deck_id_2])
  end

  test "list matches" do
    [player_created_event] =
      Player.feed(Event.new([:create, :player], %{name: "David Match"}), nil)

    player_id = player_created_event.data.out

    [deck_created_event] =
      Deck.feed(Event.new([:create, :deck], %DeckInput{name: "Delta Match", player_id: player_id, format: "standard"}), nil)

    deck_id = deck_created_event.data.id

    Match.feed(
      Event.new([:create, :match], %{
        player_1_id: player_id,
        deck_1_id: deck_id,
        player_2_id: player_id,
        deck_2_id: deck_id,
        ranking: false
      }),
      nil
    )

    Match.feed(
      Event.new([:create, :match], %{
        player_1_id: player_id,
        deck_1_id: deck_id,
        player_2_id: player_id,
        deck_2_id: deck_id,
        ranking: true
      }),
      nil
    )

    Match.feed(
      Event.new([:create, :match], %{
        player_1_id: player_id,
        deck_1_id: deck_id,
        player_2_id: player_id,
        deck_2_id: deck_id,
        ranking: false
      }),
      nil
    )

    [match_list_event] = Stately.feed(Event.new([:list, :match], %{}), nil)
    matches = match_list_event.data.matches
    assert 3 = Enum.count(matches)

    Data.wipe_test("Match", Enum.map(matches, fn m -> m.id end))
    Data.wipe_test("Player", player_id)
    Data.wipe_test("Deck", deck_id)
  end
end

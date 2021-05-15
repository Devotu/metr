defmodule MatchTest do
  use ExUnit.Case

  alias Metr.Modules.Deck
  alias Metr.Modules.Match
  alias Metr.Event
  alias Metr.Modules.Player
  alias Metr.Modules.Stately
  alias Metr.Router
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.MatchInput
  alias Metr.Modules.Input.PlayerInput

  test "basic feed" do
    assert [] == Match.feed(Event.new([:not, :relevant], %{id: "abc_123"}), nil)
  end

  test "create match" do
    [player_created_event] =
      Player.feed(Event.new([:create, :player], %PlayerInput{name: "Adam Match"}), nil)

    player_id = player_created_event.data.out

    [deck_created_event, _deck_created_response] =
      Deck.feed(Event.new([:create, :deck], %DeckInput{name: "Alpha Match", player_id: player_id, format: "standard"}), nil)

    deck_id = deck_created_event.data.id

    Router.input(
      Event.new([:create, :match], %MatchInput{
        player_one: player_id,
        deck_one: deck_id,
        player_two: player_id,
        deck_two: deck_id,
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

    TestHelper.wipe_test(:match, match_id)
    TestHelper.wipe_test(:player, player_id)
    TestHelper.wipe_test(:deck, deck_id)
  end

  test "fail create match" do
    [player_created_event] =
      Player.feed(Event.new([:create, :player], %PlayerInput{name: "Bertil Match"}), nil)

    player_id = player_created_event.data.out

    [deck_1_created_event, _deck_1_created_response] =
      Deck.feed(Event.new([:create, :deck], %DeckInput{name: "Bravo Match", player_id: player_id, format: "standard"}), nil)

    deck_id_1 = deck_1_created_event.data.id

    [deck_2_created_event, _deck_2_created_response] =
      Deck.feed(
        Event.new([:create, :deck], %DeckInput{name: "Charlie Match", player_id: player_id, format: "standard"}),
        nil
      )

    deck_id_2 = deck_2_created_event.data.id

    Metr.alter_rank(deck_id_2, :up)
    Metr.alter_rank(deck_id_2, :up)

    [resulting_event] =
      Match.feed(
        Event.new([:create, :match], %MatchInput{
          player_one: player_id,
          player_two: player_id,
          deck_one: deck_id_1,
          deck_two: deck_id_2,
          ranking: true
        }),
        nil
      )

    assert [:match, :error, nil] == resulting_event.keys
    assert "ranks does not match" == resulting_event.data.cause
    TestHelper.wipe_test(:player, player_id)
    TestHelper.wipe_test(:deck, [deck_id_1, deck_id_2])
  end

  test "list matches" do
    [player_created_event] =
      Player.feed(Event.new([:create, :player], %PlayerInput{name: "David Match"}), nil)

    player_id = player_created_event.data.out

    [deck_created_event, _deck_created_response] =
      Deck.feed(Event.new([:create, :deck], %DeckInput{name: "Delta Match", player_id: player_id, format: "standard"}), nil)

    deck_id = deck_created_event.data.id

    Match.feed(
      Event.new([:create, :match], %MatchInput{
        player_one: player_id,
        deck_one: deck_id,
        player_two: player_id,
        deck_two: deck_id,
        ranking: false
      }),
      nil
    )

    Match.feed(
      Event.new([:create, :match], %MatchInput{
        player_one: player_id,
        deck_one: deck_id,
        player_two: player_id,
        deck_two: deck_id,
        ranking: true
      }),
      nil
    )

    Match.feed(
      Event.new([:create, :match], %MatchInput{
        player_one: player_id,
        deck_one: deck_id,
        player_two: player_id,
        deck_two: deck_id,
        ranking: false
      }),
      nil
    )

    [match_list_event] = Stately.feed(Event.new([:list, :match], %{}), nil)
    matches = match_list_event.data.out
    assert 3 = Enum.count(matches)

    TestHelper.wipe_test(:match, Enum.map(matches, fn m -> m.id end))
    TestHelper.wipe_test(:player, player_id)
    TestHelper.wipe_test(:deck, deck_id)
  end
end

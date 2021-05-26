defmodule MatchTest do
  use ExUnit.Case

  alias Metr.Modules.Deck
  alias Metr.Modules.Match
  alias Metr.Event
  alias Metr.Modules.Player
  alias Metr.Modules.State
  alias Metr.Modules.Stately
  alias Metr.Router
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.MatchInput
  alias Metr.Modules.Input.PlayerInput

  test "basic feed" do
    assert [] == Match.feed(Event.new([:not, :relevant], %{id: "abc_123"}), nil)
  end

  test "create match" do
    player_id = TestHelper.init_only_player "Adam Match"
    deck_id = TestHelper.init_only_deck "Alpha Match", player_id

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
    player_id = TestHelper.init_only_player "Bertil Match"
    deck_1_id = TestHelper.init_only_deck "Bravo Match", player_id
    deck_2_id = TestHelper.init_only_deck "Charlie Match", player_id

    Metr.alter_rank(deck_2_id, :up)
    Metr.alter_rank(deck_2_id, :up)

    [resulting_event] =
      Match.feed(
        Event.new([:create, :match], %MatchInput{
          player_one: player_id,
          player_two: player_id,
          deck_one: deck_1_id,
          deck_two: deck_2_id,
          ranking: true
        }),
        nil
      )

    assert [:match, :error, nil] == resulting_event.keys
    assert "ranks does not match" == resulting_event.data.cause
    TestHelper.wipe_test(:player, player_id)
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id])
  end

  test "list matches" do
    player_id = TestHelper.init_only_player "David Match"
    deck_id = TestHelper.init_only_deck "Delta Match", player_id

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

defmodule MatchTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Deck
  alias Metr.Match
  alias Metr.Event
  alias Metr.Player
  alias Metr.Router


  test "basic feed" do
    assert [] == Match.feed Event.new([:not, :relevant], %{id: "abc_123"}), nil
  end


  test "create match" do
    [player_created_event] = Player.feed Event.new([:create, :player], %{name: "Adam Match"}), nil
    player_id = player_created_event.data.id
    [deck_created_event] = Deck.feed Event.new([:create, :deck], %{name: "Alpha Match", player_id: player_id}), nil
    deck_id = deck_created_event.data.id
    Router.input Event.new([:create, :match], %{player_1_id: player_id, deck_1_id: deck_id, player_2_id: player_id, deck_2_id: deck_id, ranking: :false})
    [read_deck_event] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_id}), nil
    deck = read_deck_event.data.out
    assert 2 == Enum.count(deck.matches)
    match_id = List.first(deck.matches)
    [read_match_event] = Match.feed Event.new([:read, :match], %{match_id: match_id}), nil
    match = read_match_event.data.out
    assert :initialized == match.status
    assert false == match.ranking
    assert deck_id == match.deck_one
    Data.wipe_test("Match", match_id)
    Data.wipe_test("Player", player_id)
    Data.wipe_test("Deck", deck_id)
  end


  test "fail create match" do
    [player_created_event] = Player.feed Event.new([:create, :player], %{name: "Bertil Match"}), nil
    player_id = player_created_event.data.id
    [deck_1_created_event] = Deck.feed Event.new([:create, :deck], %{name: "Bravo Match", player_id: player_id}), nil
    deck_id_1 = deck_1_created_event.data.id
    [deck_2_created_event] = Deck.feed Event.new([:create, :deck], %{name: "Charlie Match", player_id: player_id, rank: {1,0}}), nil
    deck_id_2 = deck_2_created_event.data.id
    [resulting_event] = Match.feed Event.new([:create, :match], %{player_1_id: player_id, deck_1_id: deck_id_1, player_2_id: player_id, deck_2_id: deck_id_2, ranking: :true}), nil
    assert [:match, :create, :fail] == resulting_event.tags
    assert "ranks does not match" == resulting_event.data.cause
    Data.wipe_test("Player", player_id)
    Data.wipe_test("Deck", [deck_id_1, deck_id_2])
  end
end

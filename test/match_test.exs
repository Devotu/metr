defmodule MatchTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Deck
  alias Metr.Match
  alias Metr.Event
  alias Metr.Player


  test "basic feed" do
    assert [] == Match.feed Event.new([:not, :relevant], %{id: "abc_123"}), nil
  end


  test "create match" do
    [player_created_event] = Player.feed Event.new([:create, :player], %{name: "Adam Match"}), nil
    player_id = player_created_event.data.id
    [deck_created_event] = Deck.feed Event.new([:create, :deck], %{name: "Alpha Match", player_id: player_id}), nil
    deck_id = deck_created_event.data.id
    [resulting_event] = Match.feed Event.new([:create, :match], %{player_1: player_id, deck_1: deck_id, player_2: player_id, deck_2: deck_id, ranking: :false}), nil
    assert [:match, :created, nil] == resulting_event.tags
    Data.wipe_test("Match", resulting_event.data.id)
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
    [resulting_event] = Match.feed Event.new([:create, :match], %{player_1: player_id, deck_1: deck_id_1, player_2: player_id, deck_2: deck_id_2, ranking: :true}), nil
    assert [:match, :create, :fail] == resulting_event.tags
    assert "ranks does not match" == resulting_event.data.cause
    Data.wipe_test("Player", player_id)
    Data.wipe_test("Deck", [deck_id_1, deck_id_2])
  end
end

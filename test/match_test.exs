defmodule MatchTest do
  use ExUnit.Case

  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.Input.MatchInput
  alias Metr.Modules.Match
  alias Metr.Modules.State

  test "basic feed" do
    assert [] == Match.feed(Event.new([:not, :relevant], %{id: "abc_123"}), nil)
  end

  test "create match" do
    player_id = TestHelper.init_only_player "Adam Match"
    deck_id = TestHelper.init_only_deck "Alpha Match", player_id

    match_input = %MatchInput{
      player_one: player_id,
      deck_one: deck_id,
      player_two: player_id,
      deck_two: deck_id,
      ranking: false
    }

    match_id = Metr.create(match_input, :match)

    deck = Metr.read(deck_id, :deck)
    assert 2 == Enum.count(deck.matches)

    [read_player_event] = State.feed(Event.new([:read, :player], %{id: player_id}), nil)
    player = read_player_event.data.out
    assert 2 == Enum.count(player.matches)

    [read_match_event] = State.feed(Event.new([:read, :match], %{id: match_id}), nil)
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

    id = Id.guid()

    resulting_event =
      Match.feed(
        Event.new([:create, :match],
        %{
          id: id,
          input: %MatchInput{
            player_one: player_id,
            player_two: player_id,
            deck_one: deck_1_id,
            deck_two: deck_2_id,
            ranking: true
          }
        }),
        nil
      )
    |> List.first()

    assert [:error, nil] == resulting_event.keys
    assert "ranks does not match" == resulting_event.data.cause
    TestHelper.wipe_test(:player, player_id)
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id])
  end

  test "list matches" do
    player_id = TestHelper.init_only_player "David Match"
    deck_id = TestHelper.init_only_deck "Delta Match", player_id

    Match.feed(
      Event.new([:create, :match],
      %{
        id: Id.guid(),
        input: %MatchInput{
          player_one: player_id,
          deck_one: deck_id,
          player_two: player_id,
          deck_two: deck_id,
          ranking: false
        }
      }),
      nil
    )

    Match.feed(
      Event.new([:create, :match],
      %{
        id: Id.guid(),
        input: %MatchInput{
          player_one: player_id,
          deck_one: deck_id,
          player_two: player_id,
          deck_two: deck_id,
          ranking: true
        }
      }),
      nil
    )

    Match.feed(
      Event.new([:create, :match],
      %{
        id: Id.guid(),
        input: %MatchInput{
          player_one: player_id,
          deck_one: deck_id,
          player_two: player_id,
          deck_two: deck_id,
          ranking: false
        }
      }),
      nil
    )

    matches = Event.new([:list, :match])
      |> State.feed(nil)
      |> List.first()
      |> Event.get_out()

    assert 3 <= Enum.count(matches)

    TestHelper.wipe_test(:match, Enum.map(matches, fn m -> m.id end))
    TestHelper.wipe_test(:player, player_id)
    TestHelper.wipe_test(:deck, deck_id)
  end
end

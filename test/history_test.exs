defmodule HistoryTest do
  use ExUnit.Case

  alias Metr.History
  alias Metr.Modules.Stately

  test "read history of entity x" do
    player_name = "Viktor Metr"
    deck_name = "Victory Metr"
    player_two_name = "Walter Metr"
    deck_two_name = "Whiskey Metr"

    {player_id, deck_id, player_two_id, deck_two_id, match_id, game_id} =
      TestHelper.init_double_state(player_name, deck_name, player_two_name, deck_two_name)

    Metr.alter_rank(deck_id, :up)

    original_deck = Stately.read(deck_id, :deck)
    :timer.sleep(1000)

    deck_history = History.of_entity :deck, deck_id

    assert is_list(deck_history)

    [creation, match_created, game_created, rank_altered] = deck_history

    assert Map.has_key?(creation, :event) and Map.has_key?(creation, :state) and Map.has_key?(creation, :data)
    assert %{name: deck_name, player_id: player_id} == creation.event.data
    assert deck_name == creation.state.name
    assert creation.state == creation.data

    assert [deck_id, deck_two_id] == match_created.event.data.deck_ids
    assert 1 == Enum.count(match_created.state.matches)
    assert match_created.state == match_created.data

    [result_id] = game_created.state.results
    assert result_id in game_created.event.data.result_ids

    assert game_created.state == game_created.data

    assert %{change: 1, deck_id: deck_id} == rank_altered.event.data
    assert deck_name == rank_altered.state.name
    assert rank_altered.state == rank_altered.data

    #Time created etc should not equal rerun
    assert List.last(deck_history).state == original_deck
    assert Stately.read(deck_id, :deck) == original_deck

    TestHelper.cleanup_double_states(
      {player_id, deck_id, player_two_id, deck_two_id, match_id, game_id}
    )
  end
end

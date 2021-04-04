defmodule HistoryTest do
  use ExUnit.Case

  test "read history of entity x" do
    player_name = "Viktor Metr"
    deck_name = "Victory Metr"
    player_two_name = "Walter Metr"
    deck_two_name = "Whiskey Metr"

    {player_id, deck_id, player_two_id, deck_two_id, match_id, game_id} =
      TestHelper.init_double_state(player_name, deck_name, player_two_name, deck_two_name)

    Metr.alter_rank(deck_id, :up)

    deck_history = Metr.read_entity_history("deck", deck_id)

    assert is_list(deck_history)

    [creation, match_created, game_created, rank_altered] = deck_history

    assert %{name: deck_name, player_id: player_id} == creation.event.data
    assert deck_name == creation.state.name
    assert creation.state == creation.data

    assert [deck_id, deck_two_id] == match_created.event.data.deck_ids
    assert 1 == Enum.count(match_created.state.matches)
    assert match_created.state == match_created.data

    [result_one_id, result_two_id] = game_created.data.result_ids

    assert result_one_id in game_created.state.results or
             result_two_id in game_created.state.results

    assert game_created.state == game_created.data

    assert %{change: 1, deck_id: deck_id} == rank_altered.event.data
    assert deck_name == rank_altered.state.name
    assert rank_altered.state == rank_altered.data

    TestHelper.cleanup_double_states(
      {player_id, deck_id, player_two_id, deck_two_id, match_id, game_id}
    )
  end
end

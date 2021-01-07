defmodule TagTest do
  use ExUnit.Case

  alias Metr.Event
  alias Metr.Data
  alias Metr.Modules.Tag

  test "tag double" do
    player_name = "Adam Tag"
    deck_name = "Alpha Tag"

    {player_id, deck_id, match_id, game_id} =
      TestHelper.init_single_states(player_name, deck_name)

    fake_pid = "pid"
    tag = "double"

    [creation_response, creation_propagation] =
      Tag.feed(Event.new([:tag, :player], %{id: player_id, tag: tag}), fake_pid)

    assert [:tag, :created, fake_pid] == creation_response.keys
    assert %{out: tag}
    assert [:player, :tagged] == creation_propagation.keys
    assert %{id: player_id, tag: tag}

    Tag.feed(creation_propagation, nil)

    [failure_response] =
      Tag.feed(Event.new([:tag, :player], %{id: player_id, tag: tag}), fake_pid)

    assert [:player, :error, fake_pid] == failure_response.keys
    assert %{msg: "duplicate tag double found on Player adam_tag"} = failure_response.data

    TestHelper.cleanup_single_states({player_id, deck_id, match_id, game_id})
    Data.wipe_test("Tag", tag)
  end
end

defmodule BadgeTest do
  use ExUnit.Case

  alias Metr.Event
  alias Metr.Data
  alias Metr.Modules.Badge
  alias Metr.Modules.Player
  alias Metr.Modules.Stately

  test "badge double" do
    player_name = "Adam Badge"
    deck_name = "Alpha Badge"

    {player_id, deck_id, match_id, game_id} =
      TestHelper.init_single_states(player_name, deck_name)

    fake_pid = "pid"
    badge = "double"

    [creation_response, first_propagation] =
      Badge.feed(Event.new([:badge, :player], %{id: player_id, badge: badge}), fake_pid)

    assert [:badge, :created, fake_pid] == creation_response.keys
    assert %{out: badge} == creation_response.data
    assert [:player, :badged] == first_propagation.keys
    assert %{id: player_id, badge: badge} == first_propagation.data

    Badge.feed(first_propagation, nil)

    #To guarantee two different timestamps
    :timer.sleep(1000)

    [second_response, second_propagation] =
      Badge.feed(Event.new([:badge, :player], %{id: player_id, badge: badge}), fake_pid)

    assert [:badge, :altered, fake_pid] == second_response.keys
    %{out: updated_badge} = second_response.data
    [t1, t2] = updated_badge.badged[player_id]
    assert is_number(t1)
    assert is_number(t2)

    Badge.feed(second_propagation, nil)
    assert [:player, :badged] == second_propagation.keys
    assert %{id: player_id, badge: badge} == second_propagation.data

    player = Stately.read(player_id, "Player")
    [ts1, ts2] = player.badges[badge]
    assert is_number(ts1)
    assert is_number(ts2)

    [third_response, third_propagation] =
      Badge.feed(Event.new([:badge, :deck], %{id: deck_id, badge: badge}), fake_pid)

    assert [:badge, :altered, fake_pid] == third_response.keys

    Badge.feed(third_propagation, nil)
    assert [:deck, :badged] == third_propagation.keys
    assert %{id: deck_id, badge: badge} == third_propagation.data

    TestHelper.cleanup_single_states({player_id, deck_id, match_id, game_id})
    Data.wipe_test("Badge", badge)
  end
end

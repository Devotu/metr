defmodule BaseTest do
  use ExUnit.Case

  alias Metr.Modules.Base
  alias Metr.Data
  alias Metr.Event
  alias Metr.Modules.Player

  test "exists" do
    assert false == Base.exist?("not yet created", "Player")
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Adam Base"}), nil)
    player_id = resulting_event.data.id
    assert true == Base.exist?(player_id, "Player")
    Data.wipe_test("Player", player_id)
  end

  test "read state" do
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Bertil Base"}), nil)
    player_id = resulting_event.data.id
    player = Base.read(player_id, "Player")
    assert player_id == player.id
    Data.wipe_test("Player", player_id)
  end

  test "ready" do
    assert {:error, "Player not_yet_created not found"} == Base.ready("not_yet_created", "Player")
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Ceasar Base"}), nil)
    player_id = resulting_event.data.id
    assert {:ok} == Base.ready(player_id, "Player")
    Data.wipe_test("Player", player_id)
  end

  test "update" do
    assert {:error, "Player not_yet_created not found"} ==
             Base.update("not_yet_created", "Player", [], %{}, %Event{})

    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "David Base"}), nil)
    player_id = resulting_event.data.id
    event = Event.new([:deck, :created, nil], %{id: "deck_id", player_id: player_id})

    assert "Deck deck_id added to player #{player_id}" ==
             Base.update(player_id, "Player", event.tags, event.data, event)

    Data.wipe_test("Player", player_id)
  end

  test "to_event" do
    expected_output = "Expected output"
    e = Base.out_to_event(expected_output, "Player", [:altered, nil])
    assert [:player, :altered, nil] == e.tags
    assert %{out: expected_output} == e.data
  end

  test "module_to_name" do
    assert Player.module_name() == "Player"
  end
end

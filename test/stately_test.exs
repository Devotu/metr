defmodule StatelyTest do
  use ExUnit.Case

  alias Metr.Modules.Stately
  alias Metr.Data
  alias Metr.Event
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Input.PlayerInput

  test "exists" do
    assert false == Stately.exist?("not yet created", :player)
    [resulting_event] = Player.feed(Event.new([:create, :player], %PlayerInput{name: "Adam Stately"}), nil)
    player_id = resulting_event.data.out
    assert true == Stately.exist?(player_id, :player)
    TestHelper.wipe_test(:player, player_id)
  end

  test "read state" do
    [resulting_event] = Player.feed(Event.new([:create, :player], %PlayerInput{name: "Bertil Stately"}), nil)
    player_id = resulting_event.data.out
    player = Stately.read(player_id, :player)
    assert player_id == player.id
    TestHelper.wipe_test(:player, player_id)
  end

  test "ready" do
    assert {:error, "Player not_yet_created not found"} ==
             Stately.ready("not_yet_created", :player)

    [resulting_event] = Player.feed(Event.new([:create, :player], %PlayerInput{name: "Ceasar Stately"}), nil)
    player_id = resulting_event.data.out
    assert {:ok} == Stately.ready(player_id, :player)
    TestHelper.wipe_test(:player, player_id)
  end

  test "update" do
    assert {:error, "Player not_yet_created not found"} ==
             Stately.update("not_yet_created", :player, [], %{}, %Event{})

    [resulting_event] = Player.feed(Event.new([:create, :player], %PlayerInput{name: "David Stately"}), nil)
    player_id = resulting_event.data.out
    event = Event.new([:deck, :created, nil], %{id: "deck_id", player_id: player_id})

    assert "Deck deck_id added to player #{player_id}" ==
             Stately.update(player_id, :player, event.keys, event.data, event)

    TestHelper.wipe_test(:player, player_id)
  end

  test "to_event" do
    expected_output = "Expected output"
    e = Stately.out_to_event(expected_output, :player, [:altered, nil])
    assert [:player, :altered, nil] == e.keys
    assert %{out: expected_output} == e.data
  end

  test "module_to_name" do
    assert Player.module_name() == :player
  end

  test "recall as correct struct" do
    player_name = "Erik Stately"
    deck_name = "Echo Stately"

    {player_id, deck_id, match_id, game_id} =
      TestHelper.init_single_states(player_name, deck_name)

    assert :ok == Data.genserver_id(:player, player_id) |> GenServer.stop()
    player = Player.read(player_id)
    assert is_struct(player, Player)

    assert :ok == Data.genserver_id(:deck, deck_id) |> GenServer.stop()
    deck = Deck.read(deck_id)
    assert is_struct(deck, Deck)

    assert :ok == Data.genserver_id(:match, match_id) |> GenServer.stop()
    match = Match.read(match_id)
    assert is_struct(match, Match)

    assert :ok == Data.genserver_id(:game, game_id) |> GenServer.stop()
    game = Game.read(game_id)
    assert is_struct(game, Game)

    result = Result.read(game.results |> List.first())
    assert is_struct(result, Result)

    TestHelper.wipe_test(:player, [player_id])
    TestHelper.wipe_test(:deck, [deck_id])
    TestHelper.wipe_test(:game, [game_id])
    TestHelper.wipe_test(:result, game.results)
    TestHelper.wipe_test(:match, match_id)
  end

  test "rerun" do
    player_name = "Fredrik Stately"
    deck_name = "Foxtrot Stately"

    {player_id, deck_id, match_id, game_id} =
      TestHelper.init_single_states(player_name, deck_name)

    original_player = Stately.read(player_id, :player)
    # To verify it is not the same state read
    Data.wipe_state([player_id], :player)
    assert {:error, "Player #{player_id} not found"} == Player.read(player_id)

    assert :ok == Stately.rerun(player_id, :player)

    recreated_player = Stately.read(player_id, :player)
    assert recreated_player == original_player

    game = Game.read(game_id)

    TestHelper.wipe_test(:player, [player_id])
    TestHelper.wipe_test(:deck, [deck_id])
    TestHelper.wipe_test(:game, [game_id])
    TestHelper.wipe_test(:result, game.results)
    TestHelper.wipe_test(:match, match_id)
  end

  test "rerun fail" do
    player_id = "fail_rerun_base"
    Stately.rerun(player_id, :player)
    assert {:error, "not found"} == Stately.rerun(player_id, :player)
  end
end

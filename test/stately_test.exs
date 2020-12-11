defmodule StatelyTest do
  use ExUnit.Case

  alias Metr.Modules.Stately
  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result

  test "exists" do
    assert false == Stately.exist?("not yet created", "Player")
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Adam Stately"}), nil)
    player_id = resulting_event.data.id
    assert true == Stately.exist?(player_id, "Player")
    Data.wipe_test("Player", player_id)
  end

  test "read state" do
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Bertil Stately"}), nil)
    player_id = resulting_event.data.id
    player = Stately.read(player_id, "Player")
    assert player_id == player.id
    Data.wipe_test("Player", player_id)
  end

  test "ready" do
    assert {:error, "Player not_yet_created not found"} == Stately.ready("not_yet_created", "Player")
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Ceasar Stately"}), nil)
    player_id = resulting_event.data.id
    assert {:ok} == Stately.ready(player_id, "Player")
    Data.wipe_test("Player", player_id)
  end

  test "update" do
    assert {:error, "Player not_yet_created not found"} ==
             Stately.update("not_yet_created", "Player", [], %{}, %Event{})

    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "David Stately"}), nil)
    player_id = resulting_event.data.id
    event = Event.new([:deck, :created, nil], %{id: "deck_id", player_id: player_id})

    assert "Deck deck_id added to player #{player_id}" ==
             Stately.update(player_id, "Player", event.tags, event.data, event)

    Data.wipe_test("Player", player_id)
  end

  test "to_event" do
    expected_output = "Expected output"
    e = Stately.out_to_event(expected_output, "Player", [:altered, nil])
    assert [:player, :altered, nil] == e.tags
    assert %{out: expected_output} == e.data
  end

  test "module_to_name" do
    assert Player.module_name() == "Player"
  end

  test "recall player" do
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Erik Player"}), nil)
    player_id = resulting_event.data.id
    assert :ok == Data.genserver_id("Player", player_id) |> GenServer.stop()
    player = Player.read(player_id)

    assert is_struct(player, Player)

    [resulting_event] = Deck.feed(Event.new([:create, :deck], %{name: "Filip Deck", player_id: player_id}), nil)
    deck_id = resulting_event.data.id
    assert :ok == Data.genserver_id("Deck", deck_id) |> GenServer.stop()
    deck = Deck.read(deck_id)

    assert is_struct(deck, Deck)

    Data.wipe_test("Player", player_id)
    Data.wipe_test("Deck", deck_id)

    player_name = "Niklas Game"
    player_id = Id.hrid(player_name)
    deck_name = "November Game"
    deck_id = Id.hrid(deck_name)

    Player.feed(Event.new([:create, :player], %{name: player_name}), nil)
    Deck.feed(Event.new([:create, :deck], %{name: deck_name, player_id: player_id}), nil)

    game_1_input = %{
      deck_1: deck_id,
      deck_2: deck_id,
      player_1: player_id,
      player_2: player_id,
      balance: 1,
      winner: 2
    }

    {:error, "invalid input balance"} = Metr.create_game(game_1_input)

    game_2_input = %{
      deck_1: deck_id,
      deck_2: deck_id,
      player_1: player_id,
      player_2: player_id,
      balance: "2",
      winner: 2
    }

    {:error, "invalid input balance"} = Metr.create_game(game_2_input)

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
  end

  test "recall as correct struct" do
    player_name = "Erik Stately"
    deck_name = "Echo Stately"
    {player_id, deck_id, match_id, game_id} = TestHelper.init_single_states(player_name, deck_name)

    assert :ok == Data.genserver_id("Player", player_id) |> GenServer.stop()
    player = Player.read(player_id)
    assert is_struct(player, Player)

    assert :ok == Data.genserver_id("Deck", deck_id) |> GenServer.stop()
    deck = Deck.read(deck_id)
    assert is_struct(deck, Deck)

    assert :ok == Data.genserver_id("Match", match_id) |> GenServer.stop()
    match = Match.read(match_id)
    assert is_struct(match, Match)

    assert :ok == Data.genserver_id("Game", game_id) |> GenServer.stop()
    game = Game.read(game_id)
    assert is_struct(game, Game)

    result = Result.read(game.results |> List.first)
    assert is_struct(result, Result)

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
    Data.wipe_test("Game", [game_id])
    Data.wipe_test("Result", game.results)
    Data.wipe_test("Match", match_id)
  end


  test "rerun" do
    player_name = "Fredrik Stately"
    deck_name = "Foxtrot Stately"
    {player_id, deck_id, match_id, game_id} = TestHelper.init_single_states(player_name, deck_name)

    original_player = Stately.read(player_id, "Player")
    Data.wipe_state("Player", [player_id]) #To verify it is not the same state read
    assert {:error, "Player #{player_id} not found"} == Player.read(player_id)

    assert :ok == Stately.rerun(player_id, "Player")

    recreated_player = Stately.read(player_id, "Player")
    assert recreated_player == original_player

    game = Game.read(game_id)

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
    Data.wipe_test("Game", [game_id])
    Data.wipe_test("Result", game.results)
    Data.wipe_test("Match", match_id)
  end

  test "rerun fail" do
    player_id = "fail_rerun_base"
    Stately.rerun(player_id, "Player")
    assert {:error, "Player #{player_id} not found"} == Stately.rerun(player_id, "Player")
  end
end

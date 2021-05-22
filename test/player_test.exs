defmodule PlayerTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Player
  alias Metr.Modules.State
  alias Metr.Modules.Stately
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.PlayerInput

  test "basic feed" do
    assert [] == Player.feed(Event.new([:not, :relevant], %{id: "abc_123"}), nil)
  end

  test "create player" do
    [resulting_event] = State.feed(Event.new([:create, :player], %PlayerInput{name: "Testy"}), nil)
    |> IO.inspect(label: "player test created")
    assert [:player, :created, nil] == resulting_event.keys
    log_entries = Data.read_log_by_id(resulting_event.data.out, :player)
    assert 1 = Enum.count(log_entries)
    # TestHelper.wipe_test(:player, resulting_event.data.out)
  end

  test "deck created" do
    # var
    player_id = "deck_owner"
    deck_id = "player_deck"
    # Player to own the deck
    [player_created_event] =
      Player.feed(Event.new([:create, :player], %PlayerInput{name: "Deck owner"}), nil)

    # Resolve deck created
    [resulting_event] =
      Player.feed(Event.new([:deck, :created, nil], %{id: deck_id, player_id: player_id}), nil)

    # Assert
    resulting_feedback_should_be = "Deck #{deck_id} added to player #{player_id}"
    assert [:player, :altered, nil] == resulting_event.keys
    assert resulting_feedback_should_be == resulting_event.data.out
    # Cleanup
    TestHelper.wipe_test(:player, player_created_event.data.out)
  end

  test "game created" do
    # var
    # Players to participate
    player_one_name = "Filip Player"
    deck_one_name = "Foxtrot Player"
    player_two_name = "Gustav Player"
    deck_two_name = "Golf Player"

    {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id} =
      TestHelper.init_double_state(player_one_name, deck_one_name, player_two_name, deck_two_name)

    # Resolve game created
    [game_created_event, _game_created_return] =
      Game.feed(
        Event.new([:create, :game], %GameInput{
          player_one: player_one_id,
          player_two: player_two_id,
          deck_one: deck_one_id,
          deck_two: deck_two_id,
          power_one: 2,
          power_two: 1,
          fun_one: -1,
          fun_two: 2,
          winner: 2,
          ranking: false
        }),
        nil
      )

    resulting_events = Player.feed(game_created_event, nil)
    first_resulting_event = List.first(resulting_events)
    player_log = Data.read_log_by_id(player_one_id, :player)

    [first_result_id, _second_result_event] = game_created_event.data.result_ids

    # Assert
    assert 2 == Enum.count(resulting_events)
    assert [:player, :altered, nil] == first_resulting_event.keys

    assert "Result #{first_result_id} added to player #{player_one_id}" ==
             first_resulting_event.data.out

    assert 3 + 2 == Enum.count(player_log) # init (3) + result added (2)

    # Cleanup
    TestHelper.wipe_test(:game, game_created_event.data.id)
    TestHelper.wipe_test(:result, game_created_event.data.result_ids)
    TestHelper.cleanup_double_states(
      {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id}
    )
  end

  test "list players" do
    Player.feed(Event.new([:create, :player], %PlayerInput{name: "Adam List"}), nil)
    Player.feed(Event.new([:create, :player], %PlayerInput{name: "Bertil List"}), nil)
    Player.feed(Event.new([:create, :player], %PlayerInput{name: "Ceasar List"}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: "Alpha List", player_id: "adam_list", format: "standard"}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: "Beta List", player_id: "bertil_list", format: "standard"}), nil)
    fake_pid = "#123"
    [resulting_event] = Stately.feed(Event.new([:list, :player]), fake_pid)
    assert [:player, :list, fake_pid] == resulting_event.keys
    # any actual data will break proper comparison
    assert 3 <= Enum.count(resulting_event.data.out)
    TestHelper.wipe_test(:player, ["adam_list", "bertil_list", "ceasar_list"])
    TestHelper.wipe_test(:deck, ["alpha_list", "beta_list"])
  end

  test "recall player" do
    expected_player = %Metr.Modules.Player{
      decks: [],
      id: "david_player",
      matches: [],
      name: "David Player",
      results: [],
      time: 0
    }

    [resulting_event] = Player.feed(Event.new([:create, :player], %PlayerInput{name: "David Player"}), nil)
    player_id = resulting_event.data.out
    gen_id = Data.genserver_id(:player, player_id)
    assert :ok == GenServer.stop(gen_id)
    assert nil == GenServer.whereis(gen_id)

    read_player = Player.read(player_id)

    assert read_player.id == expected_player.id
    assert read_player.name == expected_player.name
    assert read_player.results == expected_player.results
    assert read_player.matches |> Enum.count() == 0

    TestHelper.wipe_test(:player, player_id)
  end
end

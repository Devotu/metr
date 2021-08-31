defmodule PlayerTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.Deck
  alias Metr.Modules.Player
  alias Metr.Modules.State
  alias Metr.Modules.Stately
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.PlayerInput

  test "basic feed" do
    assert [] == State.feed(Event.new([:not, :relevant], %{id: "abc_123"}), nil)
  end

  test "create player" do
    resulting_event =
      Player.feed(
        Event.new([:create, :player],
        %{
          id: Id.guid(),
          input: %PlayerInput{
            name: "Adam Player"
          }
        }),
        nil
      )
    |> List.first()

    assert [:player, :created, nil] == resulting_event.keys
    log_entries = Data.read_log_by_id(resulting_event.data.out, :player)
    assert 1 = Enum.count(log_entries)

    TestHelper.delay()
    TestHelper.wipe_test(:player, resulting_event.data.out)
  end

  test "deck created" do
    player_id = TestHelper.init_only_player "Bertil Player"
    deck_id = TestHelper.init_only_deck "Bravor Player", player_id

    # Resolve deck created
    [resulting_event] =
      Player.feed(Event.new([:deck, :created, nil], %{out: deck_id}), nil)

    # Assert
    resulting_feedback_should_be = "Deck #{deck_id} added to player #{player_id}"
    assert [:player, :altered, nil] == resulting_event.keys
    assert resulting_feedback_should_be == resulting_event.data.out

    # Cleanup
    TestHelper.delay()
    TestHelper.wipe_test(:player, player_id)
    TestHelper.wipe_test(:deck, deck_id)
  end

  test "game created" do
    player_one_name = "Filip Player"
    deck_one_name = "Foxtrot Player"
    player_two_name = "Gustav Player"
    deck_two_name = "Golf Player"

    {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id} =
      TestHelper.init_double_state(player_one_name, deck_one_name, player_two_name, deck_two_name)

    # Above includes a game created ant thus the following should be true
    player = Metr.read(player_one_id, :player)
    [result_1_id] = player.results
    result_1 = Metr.read(result_1_id, :result)
    assert game_id == result_1.game_id

    player_log = Data.read_log_by_id(player_one_id, :player)
    assert 3 + 1 == Enum.count(player_log) # init (3) + result added (1)

    [_player_created_event, _deck_created_event, _match_created_event, result_1_created_event] = player_log

    assert [:result, :created, nil] == result_1_created_event.keys
    assert result_1_id == result_1_created_event.data.out

    # Cleanup
    TestHelper.delay()
    TestHelper.wipe_test(:result, player.results)
    TestHelper.cleanup_double_states(
      {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id}
    )
  end

  test "list players" do
    pid1 = Id.guid()
    pid2 = Id.guid()
    pid3 = Id.guid()
    did1 = Id.guid()
    did2 = Id.guid()

    Player.feed(Event.new([:create, :player], %{id: pid1, input: %PlayerInput{name: "Adam List"}}), nil)
    Player.feed(Event.new([:create, :player], %{id: pid2, input: %PlayerInput{name: "Bertil List"}}), nil)
    Player.feed(Event.new([:create, :player], %{id: pid3, input: %PlayerInput{name: "Ceasar List"}}), nil)
    Deck.feed(Event.new([:create, :deck], %{id: did1, input: %DeckInput{name: "Beta List", player_id: "bertil_list", format: "standard"}}), nil)
    Deck.feed(Event.new([:create, :deck], %{id: did2, input: %DeckInput{name: "Alpha List", player_id: "adam_list", format: "standard"}}), nil)

    [resulting_event] = State.feed(Event.new([:list, :player]), nil)
    assert [:player, :list, nil] == resulting_event.keys
    # any actual data will break proper comparison
    assert 3 <= Enum.count(resulting_event.data.out)

    TestHelper.delay()
    TestHelper.wipe_test(:player, [pid1, pid2, pid3])
    TestHelper.wipe_test(:deck, [did1, did2])
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

    [resulting_event] = Player.feed(Event.new([:create, :player], %{id: Id.guid(), input: %PlayerInput{name: "David Player"}}), nil)
    player_id = resulting_event.data.out
    gen_id = Data.genserver_id(:player, player_id)
    assert :ok == GenServer.stop(gen_id)
    assert nil == GenServer.whereis(gen_id)

    read_player = State.read(player_id, :player)

    assert read_player.name == expected_player.name
    assert read_player.results == expected_player.results
    assert read_player.matches |> Enum.count() == 0

    TestHelper.delay()
    TestHelper.wipe_test(:player, player_id)
  end
end

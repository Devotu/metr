defmodule PlayerTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event
  alias Metr.Deck
  alias Metr.Game
  alias Metr.Id
  alias Metr.Player


  test "basic feed" do
    assert [] == Player.feed Event.new([:not, :relevant], %{id: "abc_123"}), nil
  end


  test "create player" do
    [resulting_event] = Player.feed Event.new([:create, :player], %{name: "Testy"}), nil
    assert [:player, :created, nil] == resulting_event.tags
    log_entries = Data.read_log_by_id("Player", resulting_event.data.id)
    assert 1 = Enum.count(log_entries)
    Data.wipe_test("Player", resulting_event.data.id)
  end


  test "deck created" do
    #var
    player_id = "deck_owner"
    deck_id = "player_deck"
    #Player to own the deck
    [player_created_event] = Player.feed Event.new([:create, :player], %{name: "Deck owner"}), nil
    #Resolve deck created
    [resulting_event] = Player.feed Event.new([:deck, :created, nil], %{id: deck_id, player_id: player_id}), nil
    #Assert
    resulting_feedback_should_be = "Deck #{deck_id} added to player #{player_id}"
    assert [:player, :altered] == resulting_event.tags
    assert resulting_feedback_should_be == resulting_event.data.out
    #Cleanup
    Data.wipe_test("Player", player_created_event.data.id)
  end


  test "game created" do
    #var
    #Players to participate
    player_1_name = "Filip"
    player_1_id = Id.hrid(player_1_name)
    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    player_two_name = "Gustav"
    player_two_id = Id.hrid(player_two_name)
    Player.feed Event.new([:create, :player], %{name: player_two_name}), nil
    #Resolve game created

    [game_created_event] = Game.feed Event.new([:create, :game], %{
          parts: [
            %{details: %{deck_id: "festering", power: 2, fun: -1, player_id: player_1_id}, part: 1},
            %{details: %{deck_id: "gloom", power: 1, fun: 2, player_id: player_two_id}, part: 2}
          ],
          winner: 2,
          rank: false
        }), nil

    resulting_events = Player.feed(game_created_event, nil)
    first_resulting_event = List.first(resulting_events)
    player_log = Data.read_log_by_id("Player", player_1_id)


    #Assert
    assert 2 == Enum.count(resulting_events)
    assert [:player, :altered] == first_resulting_event.tags
    assert "Game #{game_created_event.data.id} added to player #{player_1_id}" == first_resulting_event.data.out
    assert 2 == Enum.count(player_log)

    #Cleanup
    Data.wipe_test("Player", [player_1_id, player_two_id])
    Data.wipe_test("Game", game_created_event.data.id)
  end


  test "list players" do
    Player.feed Event.new([:create, :player], %{name: "Adam List"}), nil
    Player.feed Event.new([:create, :player], %{name: "Bertil List"}), nil
    Player.feed Event.new([:create, :player], %{name: "Ceasar List"}), nil
    Deck.feed Event.new([:create, :deck], %{name: "Alpha List", player_id: "adam_list"}), nil
    Deck.feed Event.new([:create, :deck], %{name: "Beta List", player_id: "bertil_list"}), nil
    fake_pid = "#123"
    [resulting_event] = Player.feed Event.new([:list, :player]), fake_pid
    assert [:players, fake_pid] == resulting_event.tags
    assert 3 <= Enum.count(resulting_event.data.players) #any actual data will break proper comparison
    Data.wipe_test("Player", ["adam_list", "bertil_list", "ceasar_list"])
    Data.wipe_test("Deck", ["alpha_list", "beta_list"])
  end
end

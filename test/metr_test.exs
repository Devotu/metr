defmodule MetrTest do
  use ExUnit.Case

  alias Metr.Event
  alias Metr.Data
  alias Metr.Deck
  alias Metr.Player

  test "list players" do
    assert is_list Metr.list_players()
  end

  test "list decks" do
    assert is_list Metr.list_decks()
  end

  test "list games" do
    assert is_list Metr.list_games()
  end

  test "create game" do
    player_one_name = "David Metr"
    player_one_id = "david_metr"
    deck_one_name = "Delta Metr"
    deck_one_id = "delta_metr"

    player_two_name = "Erik Metr"
    player_two_id = "erik_metr"
    deck_two_name = "Echo Metr"
    deck_two_id = "echo_metr"

    Player.feed Event.new([:create, :player], %{name: player_one_name})
    Player.feed Event.new([:create, :player], %{name: player_two_name})
    Deck.feed Event.new([:create, :deck], %{name: deck_one_name, player_id: player_one_id})
    Deck.feed Event.new([:create, :deck], %{name: deck_two_name, player_id: player_two_id})

    game_one = %{
      :deck_1 => deck_one_id,
      :deck_2 => deck_two_id,
      :player_1 => player_one_id,
      :player_2 => player_two_id,
      :winner => 2}
    game_one_id = Metr.create_game(game_one)

    # assert :ok == status
    assert 15 = String.length(game_one_id)

    game_two = %{
      :deck_1 => deck_one_id,
      :deck_2 => deck_two_id,
      :fun_1 => 1,
      :fun_2 => -2,
      :player_1 => player_one_id,
      :player_2 => player_two_id,
      :power_1 => 2,
      :power_2 => -2,
      :winner => 1}
    game_two_id = Metr.create_game(game_two)

    # assert :ok == status
    assert 15 = String.length(game_two_id)

    Data.wipe_state("Player", player_one_id)
    Data.wipe_state("Player", player_two_id)
    Data.wipe_state("Deck", deck_one_id)
    Data.wipe_state("Deck", deck_two_id)
    Data.wipe_state("Game", game_one_id)
    Data.wipe_state("Game", game_two_id)
  end
end

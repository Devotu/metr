defmodule MetrTest do
  use ExUnit.Case

  alias Metr.Event
  alias Metr.Data
  alias Metr.Deck
  alias Metr.Player
  alias Metr.Id

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
    player_1_name = "David Metr"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Delta Metr"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Erik Metr"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "Echo Metr"
    deck_2_id = Id.hrid(deck_2_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil

    game_1 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_1_id = Metr.create_game(game_1)

    # assert :ok == status
    assert 15 = String.length(game_1_id)

    game_2 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :fun_1 => 1,
      :fun_2 => -2,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :power_1 => 2,
      :power_2 => -2,
      :winner => 1}
    game_2_id = Metr.create_game(game_2)

    games = Metr.list_games()

    assert 15 = String.length(game_2_id)

    assert 1 == Enum.filter(games, fn g -> String.equivalent?(g.id, game_2_id) end) |> Enum.count()

    [deck_1] = Metr.list_decks() |> Enum.filter(fn d -> String.equivalent?(d.id, deck_1_id) end)
    [player_2] = Metr.list_players() |> Enum.filter(fn p -> String.equivalent?(p.id, player_2_id) end)

    assert 2 == Enum.count(deck_1.games)
    assert 2 == Enum.count(player_2.games)

    Data.wipe_state("Player", player_1_id)
    Data.wipe_state("Player", player_2_id)
    Data.wipe_state("Deck", deck_1_id)
    Data.wipe_state("Deck", deck_2_id)
    Data.wipe_state("Game", game_1_id)
    Data.wipe_state("Game", game_2_id)
  end


  test "delete game" do
    player_1_name = "Filip Metr"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Foxtrot Metr"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Gustav Metr"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "Golf Metr"
    deck_2_id = Id.hrid(deck_2_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil

    game = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_id = Metr.create_game(game)
    assert game_id == Metr.delete_game(game_id)

    deck_1 = Metr.read_deck(deck_1_id)
    assert 0 == Enum.count(deck_1.games)

    player_1 = Metr.read_player(player_1_id)
    assert 0 == Enum.count(player_1.games)

    assert :error == Metr.delete_game("not an actual game id")

    games = Metr.list_games()
    assert 0 == Enum.filter(games, fn g -> String.equivalent?(g.id, game_id) end) |> Enum.count()

    Data.wipe_state("Player", player_1_id)
    Data.wipe_state("Player", player_2_id)
    Data.wipe_state("Deck", deck_1_id)
    Data.wipe_state("Deck", deck_2_id)
  end



  test "list games by deck" do
    player_1_name = "Helge Metr"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Hotel Metr"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Ivar Metr"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "India Metr"
    deck_2_id = Id.hrid(deck_2_name)

    player_3_name = "Johan Metr"
    player_3_id = Id.hrid(player_3_name)
    deck_3_name = "Juliett Metr"
    deck_3_id = Id.hrid(deck_3_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_3_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_3_name, player_id: player_3_id}), nil

    #1 vs 2
    game_1 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_1_id = Metr.create_game(game_1)


    #1 vs 3
    game_2 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_3_id,
      :fun_1 => 1,
      :fun_2 => -2,
      :player_1 => player_1_id,
      :player_2 => player_3_id,
      :power_1 => 2,
      :power_2 => -2,
      :winner => 1}
    game_2_id = Metr.create_game(game_2)

    assert 2 == Enum.count(Metr.list_games())
    assert 2 == Enum.count(Metr.list_games(:deck, deck_1_id))
    assert 1 == Enum.count(Metr.list_games(:deck, deck_2_id))

    Data.wipe_state("Player", player_1_id)
    Data.wipe_state("Player", player_2_id)
    Data.wipe_state("Player", player_3_id)
    Data.wipe_state("Deck", deck_1_id)
    Data.wipe_state("Deck", deck_2_id)
    Data.wipe_state("Deck", deck_3_id)
    Data.wipe_state("Game", game_1_id)
    Data.wipe_state("Game", game_2_id)
  end
end

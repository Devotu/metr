defmodule GameTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Deck
  alias Metr.Event
  alias Metr.Game
  alias Metr.HRC
  alias Metr.Id
  alias Metr.Player

  test "create game" do
    hcr = HRC.parse("""
    create game
      with
        part 1
        player_id erik
        and deck_id evil
        and power positive
        and fun bad
      with
        part 2
        player_id fredrik
        and deck_id fungus
      with winner 2
    """)
    assert is_struct(hcr)
    assert hcr.action == :create
    assert hcr.subject == :game
    assert hcr.details == %{winner: 2}
    assert hcr.parts ==
      [
        %{part: 1, details: %{deck_id: "evil", player_id: "erik", power: 1, fun: -2}},
        %{part: 2, details: %{deck_id: "fungus", player_id: "fredrik"}}
      ]

    [resulting_event] = Game.feed Event.new(hcr), nil
    assert [:game, :created, nil] == resulting_event.tags
    assert ["erik", "fredrik"] == resulting_event.data.player_ids
    assert ["evil", "fungus"] == resulting_event.data.deck_ids
    assert is_bitstring(resulting_event.id)
    Data.wipe_state("Game", resulting_event.data.id)
  end

  test "select last x games" do
    player_1_name = "Gustav Game"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Golf Game"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Helge Game"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "Hotel Game"
    deck_2_id = Id.hrid(deck_2_name)

    player_3_name = "Ivar Metr"
    player_3_id = Id.hrid(player_3_name)
    deck_3_name = "India Metr"
    deck_3_id = Id.hrid(deck_3_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_3_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_3_name, player_id: player_3_id}), nil

    #1
    game_1 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_1_id = Metr.create_game(game_1)

    #2
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

    #3
    game_3 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_3_id = Metr.create_game(game_3)

    #4
    game_4 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 1}
    game_4_id = Metr.create_game(game_4)

    #5
    game_5 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_5_id = Metr.create_game(game_5)

    assert 3 == Enum.count(Metr.list_games(3))

    Data.wipe_state("Player", [player_1_id, player_2_id, player_3_id])
    Data.wipe_state("Deck", [deck_1_id, deck_2_id, deck_3_id])
    Data.wipe_state("Game", [game_1_id, game_2_id, game_3_id, game_4_id, game_5_id])
  end


  test "select games by deck" do
    player_1_name = "Johan Game"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Juliet Game"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Kalle Game"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "Kilo Game"
    deck_2_id = Id.hrid(deck_2_name)

    player_3_name = "Ludvig Metr"
    player_3_id = Id.hrid(player_3_name)
    deck_3_name = "Lima Metr"
    deck_3_id = Id.hrid(deck_3_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_3_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_3_name, player_id: player_3_id}), nil

    #1v2
    game_1 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_1_id = Metr.create_game(game_1)

    #1v3
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

    #1v2
    game_3 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_3_id = Metr.create_game(game_3)

    #1v2
    game_4 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 1}
    game_4_id = Metr.create_game(game_4)

    #1v2
    game_5 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_5_id = Metr.create_game(game_5)

    assert 4 == Enum.count(Metr.list_games(:deck, deck_2_id))

    Data.wipe_state("Player", [player_1_id, player_2_id, player_3_id])
    Data.wipe_state("Deck", [deck_1_id, deck_2_id, deck_3_id])
    Data.wipe_state("Game", [game_1_id, game_2_id, game_3_id, game_4_id, game_5_id])
  end
end
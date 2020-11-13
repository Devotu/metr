defmodule GameTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Deck
  alias Metr.Event
  alias Metr.Game
  alias Metr.HRC
  alias Metr.Id
  alias Metr.Player
  alias Metr.Result

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
    assert is_bitstring(resulting_event.id)
    Data.wipe_test("Game", resulting_event.data.id)
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

    player_3_name = "Ivar Game"
    player_3_id = Id.hrid(player_3_name)
    deck_3_name = "India Game"
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

    Data.wipe_test("Player", [player_1_id, player_2_id, player_3_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id, deck_3_id])
    Data.wipe_test("Game", [game_1_id, game_2_id, game_3_id, game_4_id, game_5_id])
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

    player_3_name = "Ludvig Game"
    player_3_id = Id.hrid(player_3_name)
    deck_3_name = "Lima Game"
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

    assert 4 == Enum.count(Metr.list_states(:game, :deck, deck_2_id))

    results = Metr.list_results()

    Data.wipe_test("Player", [player_1_id, player_2_id, player_3_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id, deck_3_id])
    Data.wipe_test("Game", [game_1_id, game_2_id, game_3_id, game_4_id, game_5_id])
    Data.wipe_test("Result", Enum.map(results, fn r -> r.id end))
  end


  test "game with balance" do
    player_name = "Martin Game"
    player_id = Id.hrid(player_name)
    deck_name = "Mike Game"
    deck_id = Id.hrid(deck_name)

    Player.feed Event.new([:create, :player], %{name: player_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_name, player_id: player_id}), nil

    game_1_input = %{
      deck_1: deck_id,
      deck_2: deck_id,
      player_1: player_id,
      player_2: player_id,
      balance: {2,1},
      winner: 2}
    game_1_id = Metr.create_game(game_1_input)
    game_1 = Metr.read_game(game_1_id)
    [result_11_id, result_12_id] = game_1.results
    result_11 = Result.read(result_11_id)
    result_12 = Result.read(result_12_id)
    assert -1 == result_11.power
    assert 1 == result_12.power

    game_2_input = %{
      deck_1: deck_id,
      deck_2: deck_id,
      player_1: player_id,
      player_2: player_id,
      balance: nil,
      winner: 2}
    game_2_id = Metr.create_game(game_2_input)
    game_2 = Metr.read_game(game_2_id)
    [result_21_id, result_22_id] = game_2.results
    result_21 = Result.read(result_21_id)
    result_22 = Result.read(result_22_id)
    assert nil == result_21.power
    assert nil == result_22.power

    game_3_input = %{
      deck_1: deck_id,
      deck_2: deck_id,
      player_1: player_id,
      player_2: player_id,
      winner: 2}
    game_3_id = Metr.create_game(game_3_input)
    game_3 = Metr.read_game(game_3_id)
    [result_31_id, result_32_id] = game_3.results
    result_31 = Result.read(result_31_id)
    result_32 = Result.read(result_32_id)
    assert nil == result_31.power
    assert nil == result_32.power

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
    Data.wipe_test("Game", [game_1_id, game_2_id, game_3_id])
    Data.wipe_test("Result", [result_11_id, result_12_id, result_21_id, result_22_id, result_31_id, result_32_id])
  end


  test "game with failing balance" do
    player_name = "Niklas Game"
    player_id = Id.hrid(player_name)
    deck_name = "November Game"
    deck_id = Id.hrid(deck_name)

    Player.feed Event.new([:create, :player], %{name: player_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_name, player_id: player_id}), nil

    game_1_input = %{
      deck_1: deck_id,
      deck_2: deck_id,
      player_1: player_id,
      player_2: player_id,
      balance: 1,
      winner: 2}
      {:error, "invalid input balance"} = Metr.create_game(game_1_input)

    game_2_input = %{
      deck_1: deck_id,
      deck_2: deck_id,
      player_1: player_id,
      player_2: player_id,
      balance: "2",
      winner: 2}
    {:error, "invalid input balance"} = Metr.create_game(game_2_input)

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
  end
end

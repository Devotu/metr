defmodule GameTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Modules.Deck
  alias Metr.Event
  alias Metr.Modules.Game
  alias Metr.Id
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.MatchInput

  test "create game" do
    player_name = "Erik Game"
    deck_name = "Echo Game"
    player_two_name = "Fredrik Game"
    deck_two_name = "Foxtrot Game"

    {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id} =
      TestHelper.init_double_state(player_name, deck_name, player_two_name, deck_two_name)

    game_input = %GameInput{
      player_one: player_one_id,
      player_two: player_two_id,
      deck_one: deck_one_id,
      deck_two: deck_two_id,
      power_one: 1,
      fun_one: -2,
      winner: 2
    }

    [resulting_event] = Game.feed(Event.new([:create, :game], game_input), nil)
    assert [:game, :created, nil] == resulting_event.keys
    assert is_bitstring(resulting_event.id)
    Data.wipe_test("Game", resulting_event.data.id)
    Data.wipe_test("Result", resulting_event.data.result_ids)
    TestHelper.cleanup_double_states(
      {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id}
    )
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

    Player.feed(Event.new([:create, :player], %{name: player_1_name}), nil)
    Player.feed(Event.new([:create, :player], %{name: player_2_name}), nil)
    Player.feed(Event.new([:create, :player], %{name: player_3_name}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_1_name, player_id: player_1_id, format: "standard"}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_2_name, player_id: player_2_id, format: "standard"}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_3_name, player_id: player_3_id, format: "standard"}), nil)

    # 1
    game_1_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create_game()

    # 2
    game_2_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_3_id,
      player_one: player_1_id,
      player_two: player_3_id,
      winner: 1,
      power_one: 2,
      power_two: 2,
      fun_one: 1,
      fun_two: 2
    }
    |> Metr.create_game()

    # 3
    game_3_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create_game()

    # 4
    game_4_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 1
    }
    |> Metr.create_game()

    # 5
    game_5_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create_game()

    deck_1 = Metr.read(deck_1_id, :deck)
    deck_2 = Metr.read(deck_2_id, :deck)
    deck_3 = Metr.read(deck_3_id, :deck)

    assert 5 == Enum.count(deck_1.results)
    assert 3 == Enum.count(Metr.list(:game, limit: 3))

    Data.wipe_test("Player", [player_1_id, player_2_id, player_3_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id, deck_3_id])
    Data.wipe_test("Game", [game_1_id, game_2_id, game_3_id, game_4_id, game_5_id])
    Data.wipe_test("Result", deck_1.results ++ deck_2.results ++ deck_3.results)
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

    Player.feed(Event.new([:create, :player], %{name: player_1_name}), nil)
    Player.feed(Event.new([:create, :player], %{name: player_2_name}), nil)
    Player.feed(Event.new([:create, :player], %{name: player_3_name}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_1_name, player_id: player_1_id, format: "standard"}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_2_name, player_id: player_2_id, format: "standard"}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_3_name, player_id: player_3_id, format: "standard"}), nil)

    # 1v2
    game_1_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create_game()

    # 1v3
    game_2_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_3_id,
      player_one: player_1_id,
      player_two: player_3_id,
      winner: 1,
      power_one: 2,
      power_two: 2,
      fun_one: 1,
      fun_two: 2
    }
    |> Metr.create_game()

    # 1v2
    game_3_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create_game()

    # 1v2
    game_4_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 1
    }
    |> Metr.create_game()

    # 1v2
    game_5_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create_game()

    assert 4 == Enum.count(Metr.list(:game, by: {:deck, deck_2_id}))

    results = Metr.list(:result)

    Data.wipe_test("Player", [player_1_id, player_2_id, player_3_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id, deck_3_id])
    Data.wipe_test("Game", [game_1_id, game_2_id, game_3_id, game_4_id, game_5_id])
    Data.wipe_test("Result", Enum.map(results, fn r -> r.id end))
  end

  test "game with power" do
    player_name = "Martin Game"
    player_id = Id.hrid(player_name)
    deck_name = "Mike Game"
    deck_id = Id.hrid(deck_name)

    Player.feed(Event.new([:create, :player], %{name: player_name}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_name, player_id: player_id, format: "standard"}), nil)

    game_1 = %GameInput{
      player_one: player_id,
      player_two: player_id,
      deck_one: deck_id,
      deck_two: deck_id,
      winner: 2,
      power_one: -1,
      power_two: 1
    }
    |> Metr.create_game()
    |> Metr.read(:game)

    [result_11_id, result_12_id] = game_1.results
    result_11 = Result.read(result_11_id)
    result_12 = Result.read(result_12_id)
    assert -1 == result_11.power
    assert 1 == result_12.power

    game_2 = %GameInput{
      deck_one: deck_id,
      deck_two: deck_id,
      player_one: player_id,
      player_two: player_id,
      winner: 2
    }
    |> Metr.create_game()
    |> Metr.read(:game)

    [result_21_id, result_22_id] = game_2.results
    result_21 = Result.read(result_21_id)
    result_22 = Result.read(result_22_id)
    assert nil == result_21.power
    assert nil == result_22.power

    game_3 = %GameInput{
      player_one: player_id,
      player_two: player_id,
      deck_one: deck_id,
      deck_two: deck_id,
      power_one: -1,
      winner: 2
    }
    |> Metr.create_game()
    |> Metr.read(:game)

    [result_31_id, result_32_id] = game_3.results
    result_31 = Result.read(result_31_id)
    result_32 = Result.read(result_32_id)
    assert -1 == result_31.power
    assert nil == result_32.power

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
    Data.wipe_test("Game", [game_1.id, game_2.id, game_3.id])

    Data.wipe_test("Result", [
      result_11_id,
      result_12_id,
      result_21_id,
      result_22_id,
      result_31_id,
      result_32_id
    ])
  end

  test "game with failing power" do
    player_name = "Niklas Game"
    player_id = Id.hrid(player_name)
    deck_name = "November Game"
    deck_id = Id.hrid(deck_name)

    Player.feed(Event.new([:create, :player], %{name: player_name}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_name, player_id: player_id, format: "standard"}), nil)

    game_1_input = %GameInput{
      deck_one: deck_id,
      deck_two: deck_id,
      player_one: player_id,
      player_two: player_id,
      power_one: 1,
      power_two: 3,
      winner: 2
    }

    {:error, "invalid power input - power 3 is not in range"} = Metr.create_game(game_1_input) |> IO.inspect(label: "game test - inlaid input")

    game_2_input = %GameInput{
      deck_one: deck_id,
      deck_two: deck_id,
      player_one: player_id,
      player_two: player_id,
      power_one: "2",
      winner: 2
    }

    {:error, "invalid power input - power \"2\" not a number"} = Metr.create_game(game_2_input)

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
  end

  test "game in match created" do
    player_name = "Olof Game"
    player_id = Id.hrid(player_name)
    deck_name = "Oscar Game"
    deck_id = Id.hrid(deck_name)

    Player.feed(Event.new([:create, :player], %{name: player_name}), nil)
    Deck.feed(Event.new([:create, :deck], %DeckInput{name: deck_name, player_id: player_id, format: "standard"}), nil)

    [match_created_event] =
      Match.feed(
        Event.new([:create, :match], %MatchInput{
          player_one: player_id,
          player_two: player_id,
          deck_one: deck_id,
          deck_two: deck_id,
          ranking: false
        }),
        nil
      )

    match_id = match_created_event.data.id

    game_1 = %GameInput{
      player_one: player_id,
      player_two: player_id,
      deck_one: deck_id,
      deck_two: deck_id,
      winner: 2,
      match: match_id
    }
    |> Metr.create_game()
    |> Metr.read(:game)

    assert match_id == game_1.match

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
    Data.wipe_test("Game", [game_1.id])
    Data.wipe_test("Result", game_1.results)
    Data.wipe_test("Match", match_id)
  end

  test "game with turns" do
    player_name = "Peter Game"
    deck_name = "Papa Game"
    number_of_turns = Enum.random(1..50)

    {player_id, deck_id, match_id, game_id} =
      TestHelper.init_single_states(player_name, deck_name)

    game = %GameInput{
      player_one: player_id,
      player_two: player_id,
      deck_one: deck_id,
      deck_two: deck_id,
      winner: 2,
      match: match_id,
      turns: number_of_turns
    }
    |> Metr.create_game()
    |> Metr.read(:game)

    assert game.turns == number_of_turns

    TestHelper.cleanup_single_states({player_id, deck_id, match_id, game_id})
    Data.wipe_test("Game", [game.id])
    Data.wipe_test("Result", game.results)
  end
end

defmodule GameTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.State
  alias Metr.Modules.Stately
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.MatchInput
  alias Metr.Modules.Input.PlayerInput

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

    [resulting_event, _created_response] = Game.feed(Event.new([:create, :game], game_input), nil)
    assert [:game, :created, nil] == resulting_event.keys
    assert is_bitstring(resulting_event.data.id)

    [result_1_id, _result_2_id] = resulting_event.data.result_ids

    result_1 = Metr.read(result_1_id, :result)
    assert true == Stately.exist?(result_1_id, :result)

    assert resulting_event.data.id == result_1.game_id

    TestHelper.wipe_test(:game, resulting_event.data.id)
    TestHelper.wipe_test(:result, resulting_event.data.result_ids)
    TestHelper.cleanup_double_states(
      {player_one_id, deck_one_id, player_two_id, deck_two_id, match_id, game_id}
    )
  end

  test "select last x games" do
    player_1_id = TestHelper.init_only_player "Gustav Game"
    deck_1_id = TestHelper.init_only_deck "Golf Game", player_1_id

    player_2_id = TestHelper.init_only_player "Helge Game"
    deck_2_id = TestHelper.init_only_deck "Hotel Game", player_2_id

    player_3_id =  TestHelper.init_only_player "Ivar Game"
    deck_3_id = TestHelper.init_only_deck "India Game", player_3_id

    # 1
    game_1_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create(:game)

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
    |> Metr.create(:game)

    # 3
    game_3_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create(:game)

    # 4
    game_4_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 1
    }
    |> Metr.create(:game)

    # 5
    game_5_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create(:game)

    deck_1 = Metr.read(deck_1_id, :deck)
    deck_2 = Metr.read(deck_2_id, :deck)
    deck_3 = Metr.read(deck_3_id, :deck)

    assert 5 == Enum.count(deck_1.results)
    assert 3 == Enum.count(Metr.list(:game, limit: 3))

    TestHelper.wipe_test(:player, [player_1_id, player_2_id, player_3_id])
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id, deck_3_id])
    TestHelper.wipe_test(:game, [game_1_id, game_2_id, game_3_id, game_4_id, game_5_id])
    TestHelper.wipe_test(:result, deck_1.results ++ deck_2.results ++ deck_3.results)
  end

  test "select games by deck" do
    player_1_id = TestHelper.init_only_player "Johan Game"
    deck_1_id = TestHelper.init_only_deck "Juliet Game", player_1_id

    player_2_id = TestHelper.init_only_player "Kalle Game"
    deck_2_id = TestHelper.init_only_deck "Kilo Game", player_2_id

    player_3_id = TestHelper.init_only_player "Ludvig Game"
    deck_3_id = TestHelper.init_only_deck "Lima Game", player_3_id

    # 1v2
    game_1_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create(:game)

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
    |> Metr.create(:game)

    # 1v2
    game_3_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create(:game)

    # 1v2
    game_4_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 1
    }
    |> Metr.create(:game)

    # 1v2
    game_5_id = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      player_one: player_1_id,
      player_two: player_2_id,
      winner: 2
    }
    |> Metr.create(:game)

    assert 4 == Enum.count(Metr.list(:game, by: {:deck, deck_2_id}))

    results = Metr.list(:result)

    TestHelper.wipe_test(:player, [player_1_id, player_2_id, player_3_id])
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id, deck_3_id])
    TestHelper.wipe_test(:game, [game_1_id, game_2_id, game_3_id, game_4_id, game_5_id])
    TestHelper.wipe_test(:result, Enum.map(results, fn r -> r.id end))
  end

  test "game with power" do
    player_id = TestHelper.init_only_player "Martin Game"
    deck_id = TestHelper.init_only_deck "Mike Game", player_id

    game_1 = %GameInput{
      player_one: player_id,
      player_two: player_id,
      deck_one: deck_id,
      deck_two: deck_id,
      winner: 2,
      power_one: -1,
      power_two: 1
    }
    |> Metr.create(:game)
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
    |> Metr.create(:game)
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
    |> Metr.create(:game)
    |> Metr.read(:game)

    [result_31_id, result_32_id] = game_3.results
    result_31 = Result.read(result_31_id)
    result_32 = Result.read(result_32_id)
    assert -1 == result_31.power
    assert nil == result_32.power

    TestHelper.wipe_test(:player, [player_id])
    TestHelper.wipe_test(:deck, [deck_id])
    TestHelper.wipe_test(:game, [game_1.id, game_2.id, game_3.id])

    TestHelper.wipe_test(:result, [
      result_11_id,
      result_12_id,
      result_21_id,
      result_22_id,
      result_31_id,
      result_32_id
    ])
  end

  test "game with failing power" do
    player_id = TestHelper.init_only_player "Niklas Game"
    deck_id = TestHelper.init_only_deck "November Game", player_id

    game_1_input = %GameInput{
      deck_one: deck_id,
      deck_two: deck_id,
      player_one: player_id,
      player_two: player_id,
      power_one: 1,
      power_two: 3,
      winner: 2
    }

    {:error, "invalid power input - power 3 is not in range"} = Metr.create(game_1_input, :game)

    game_2_input = %GameInput{
      deck_one: deck_id,
      deck_two: deck_id,
      player_one: player_id,
      player_two: player_id,
      power_one: "2",
      winner: 2
    }

    {:error, "invalid power input - power \"2\" not a number"} = Metr.create(game_2_input, :game)

    TestHelper.wipe_test(:player, [player_id])
    TestHelper.wipe_test(:deck, [deck_id])
  end

  test "game in match created" do
    player_id = TestHelper.init_only_player "Olof Game"
    deck_id = TestHelper.init_only_deck "Oscar Game", player_id

    [match_created_event, _match_created_response] =
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
    |> Metr.create(:game)
    |> Metr.read(:game)

    assert match_id == game_1.match

    TestHelper.wipe_test(:player, [player_id])
    TestHelper.wipe_test(:deck, [deck_id])
    TestHelper.wipe_test(:game, [game_1.id])
    TestHelper.wipe_test(:result, game_1.results)
    TestHelper.wipe_test(:match, match_id)
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
    |> Metr.create(:game)
    |> Metr.read(:game)

    assert game.turns == number_of_turns

    TestHelper.cleanup_single_states({player_id, deck_id, match_id, game_id})
    TestHelper.wipe_test(:game, [game.id])
    TestHelper.wipe_test(:result, game.results)
  end

  test "draw game" do
    player_name = "Quintus Game"
    deck_name = "Qubec Game"

    {player_id, deck_id, match_id, game_id} =
      TestHelper.init_single_states(player_name, deck_name)

    game = %GameInput{
      player_one: player_id,
      player_two: player_id,
      deck_one: deck_id,
      deck_two: deck_id,
      winner: 0,
      match: match_id
    }
    |> Metr.create(:game)
    |> Metr.read(:game)

    [result_1, result_2] = Metr.list(game.results, :result)
    assert result_1.place == 0
    assert result_2.place == 0

    TestHelper.cleanup_single_states({player_id, deck_id, match_id, game_id})
    TestHelper.wipe_test(:game, [game.id])
    TestHelper.wipe_test(:result, game.results)
  end

  test "deck created" do
    player_1_id = TestHelper.init_only_player "Rudolf Game"
    player_2_id = TestHelper.init_only_player "Sigurd Game"
    deck_1_id = TestHelper.init_only_deck "Romeo Game", player_1_id
    deck_2_id = TestHelper.init_only_deck "Sierra Game", player_2_id

    [game_created_event, _game_created_response] =
      Game.feed(
        Event.new([:create, :game], %GameInput{
          player_one: player_1_id,
          player_two: player_2_id,
          deck_one: deck_1_id,
          deck_two: deck_2_id,
          power_one: -1,
          power_two: 1,
          fun_one: -2,
          fun_two: 2,
          winner: 1,
          ranking: false
        }),
        nil
      )

    resulting_events = Deck.feed(game_created_event, nil)
    first_resulting_event = List.first(resulting_events)
    deck_log = Data.read_log_by_id(deck_1_id, :deck)
    [first_result_id, _second_result_event] = game_created_event.data.result_ids

    # Assert
    assert 2 == Enum.count(resulting_events)
    assert [:deck, :altered, nil] == first_resulting_event.keys

    assert "Result #{first_result_id} added to deck #{deck_1_id}" ==
             first_resulting_event.data.out

    assert 2 == Enum.count(deck_log)

    # Cleanup
    TestHelper.wipe_test(:player, [player_1_id, player_2_id])
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id])
    TestHelper.wipe_test(:game, [game_created_event.data.id])
    TestHelper.wipe_test(:result, game_created_event.data.result_ids)
  end
end

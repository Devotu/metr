defmodule ResultTest do
  use ExUnit.Case

  alias Metr.Id
  alias Metr.Event
  alias Metr.Modules.State
  alias Metr.Modules.Deck
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.PlayerInput

  test "valid created" do
    player_id = TestHelper.init_only_player "Adam Result"
    deck_id = TestHelper.init_only_deck "Alpha Result", player_id

    game =
      Metr.create(%GameInput{
        :player_one => player_id,
        :player_two => player_id,
        :deck_one => deck_id,
        :deck_two => deck_id,
        :winner => 1,
        :fun_one => 1,
        :fun_two => -2,
        :power_one => 2,
        :power_two => -2
      }, :game)
      |> Metr.read(:game)

    result = Result.read(game.results |> List.first())

    assert 1 = result.fun
    assert 2 = result.power
    assert 1 = result.place
    assert 0 != result.time

    assert result == Metr.read(result.id, :result)
    assert result == Metr.list(game.results, :result) |> List.first()

    TestHelper.wipe_test(:deck, player_id)
    TestHelper.wipe_test(:player, deck_id)
    TestHelper.wipe_test(:game, game.id)
    TestHelper.wipe_test(:result, game.results)
  end
end

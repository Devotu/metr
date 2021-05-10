defmodule ResultTest do
  use ExUnit.Case

  alias Metr.Id
  alias Metr.Event
  alias Metr.Data
  alias Metr.Modules.Deck
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Input.GameInput

  test "valid created" do
    name = "Adam Result"
    id = Id.hrid(name)

    Player.feed(
      Event.new(
        [:create, :player],
        %{
          name: name
        }
      ),
      nil
    )

    Deck.feed(
      Event.new(
        [:create, :deck],
        %{
          name: name,
          player_id: id
        }
      ),
      nil
    )

    game =
      Metr.create_game(%GameInput{
        :player_one => id,
        :player_two => id,
        :deck_one => id,
        :deck_two => id,
        :winner => 1,
        :fun_one => 1,
        :fun_two => -2,
        :power_one => 2,
        :power_two => -2
      })
      |> Metr.read(:game)

    result = Result.read(game.results |> List.first())

    assert 1 = result.fun
    assert 2 = result.power
    assert 1 = result.place
    assert 0 != result.time

    assert result == Metr.read(result.id, :result)
    assert result == Metr.list(:result, game.results) |> List.first()

    Data.wipe_test("Deck", id)
    Data.wipe_test("Player", id)
    Data.wipe_test("Game", game.id)
    Data.wipe_test("Result", game.results)
  end
end

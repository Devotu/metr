defmodule ResultTest do
  use ExUnit.Case

  alias Metr.Id
  alias Metr.Event
  alias Metr.Data
  alias Metr.Deck
  alias Metr.Player
  alias Metr.Result


  test "valid created" do
    name = "Adam Result"
    id = Id.hrid(name)

    Player.feed(Event.new([:create, :player],
      %{
        name: name
        }), nil)

    Deck.feed(Event.new([:create, :deck],
      %{
        name: name,
        player_id: id
        }), nil)

    deck = Deck.read(id)

    game = Metr.create_game(
      %{
        :deck_1 => id,
        :deck_2 => id,
        :player_1 => id,
        :player_2 => id,
        :winner => 1,
        :fun_1 => 1,
        :fun_2 => -2,
        :power_1 => 2,
        :power_2 => -2,
      })
      |> Metr.read_state(:game)

    result = Result.read(game.results |> List.first())

    assert 1 = result.fun
    assert 2 = result.power
    assert 1 = result.place
    assert 0 != result.time

    assert result == Metr.read_state(result.id, :result)
    assert result == Metr.list_states(game.results, :result) |> List.first()

    Data.wipe_test("Deck", id)
    Data.wipe_test("Player", id)
    Data.wipe_test("Game", game.id)
    Data.wipe_test("Result", game.results)
  end
end

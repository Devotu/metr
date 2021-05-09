defmodule TimeTest do
  use ExUnit.Case

  alias Metr.Id
  alias Metr.Event
  alias Metr.Data
  alias Metr.Modules.Deck
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Input.GameInput
  alias Metr.Time

  test "state timestamps" do
    name = "Adam Time"
    id = Id.hrid(name)

    # with one second interval the entire test should pass on the same timestamp or the next
    time_of_creation = Time.timestamp()

    Player.feed(
      Event.new(
        [:create, :player],
        %{
          name: name
        }
      ),
      nil
    )

    player = Player.read(id)
    assert 0 != player.time
    assert 0 >= player.time - time_of_creation

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

    deck = Deck.read(id)
    assert 0 != deck.time
    assert 0 >= deck.time - time_of_creation

    game = %GameInput{
      deck_one: id,
      deck_two: id,
      player_one: id,
      player_two: id,
      winner: 1
    }
    |> Metr.create_game()
    |> Metr.read_state(:game)

    assert 0 != game.time
    assert 0 >= game.time - time_of_creation

    result = Result.read(game.results |> List.first())
    assert 0 != result.time
    assert 0 >= result.time - time_of_creation

    Match.feed(
      Event.new(
        [:create, :match],
        %{
          player_1_id: id,
          deck_1_id: id,
          player_2_id: id,
          deck_2_id: id,
          ranking: false
        }
      ),
      nil
    )

    match =
      Metr.list_matches()
      |> List.first()

    assert 0 != match.time
    assert 0 >= match.time - time_of_creation

    Data.wipe_test("Deck", id)
    Data.wipe_test("Player", id)
    Data.wipe_test("Game", game.id)
    Data.wipe_test("Match", match.id)
  end
end

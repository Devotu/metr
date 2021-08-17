defmodule TimeTest do
  use ExUnit.Case

  alias Metr.Id
  alias Metr.Event
  alias Metr.Modules.Match
  alias Metr.Modules.Result
  alias Metr.Modules.State
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.MatchInput
  alias Metr.Time

  test "state timestamps" do
    # with one second interval the entire test should pass on the same timestamp or the next
    time_of_creation = Time.timestamp()
    player_id = TestHelper.init_only_player "Adam Time"

    player = State.read(player_id, :player)
    assert 0 != player.time
    assert 0 >= player.time - time_of_creation

    deck_id = TestHelper.init_only_deck "Alpha Time", player_id
    deck = State.read(deck_id, :deck)
    assert 0 != deck.time
    assert 0 >= deck.time - time_of_creation

    game = %GameInput{
      player_one: player_id,
      player_two: player_id,
      deck_one: deck_id,
      deck_two: deck_id,
      winner: 1
    }
    |> Metr.create(:game)
    |> Metr.read(:game)

    assert 0 != game.time
    assert 0 >= game.time - time_of_creation

    result = Result.read(game.results |> List.first())
    assert 0 != result.time
    assert 0 >= result.time - time_of_creation

    Match.feed(
      Event.new([:create, :match],
      %{
        id: Id.guid(),
        input: %MatchInput{
          player_one: player_id,
          deck_one: deck_id,
          player_two: player_id,
          deck_two: deck_id,
          ranking: false
        }
      }),
      nil
    )

    match =
      Metr.list(:match)
      |> List.first()

    assert 0 != match.time
    assert 0 >= match.time - time_of_creation

    TestHelper.wipe_test(:deck, deck_id)
    TestHelper.wipe_test(:player, player_id)
    TestHelper.wipe_test(:game, game.id)
    TestHelper.wipe_test(:match, match.id)
  end
end

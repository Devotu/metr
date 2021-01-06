ExUnit.start()

defmodule TestHelper do

  alias Metr.Data
  alias Metr.Event
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player

  def init_single_states(player_name, deck_name) do

    [player_return] = Player.feed(Event.new([:create, :player], %{name: player_name}), nil)
    player_id = player_return.data.out

    [deck_return] = Deck.feed(Event.new([:create, :deck], %{name: deck_name, player_id: player_id}), nil)
    deck_id = deck_return.data.id

    [match_return] =
      Match.feed(
        Event.new([:create, :match], %{
          player_1_id: player_id,
          deck_1_id: deck_id,
          player_2_id: player_id,
          deck_2_id: deck_id,
          ranking: false
        }),
        nil
      )
    match_id = match_return.data.id

    game_input = %{
      deck_1: deck_id,
      deck_2: deck_id,
      player_1: player_id,
      player_2: player_id,
      winner: 2,
      match: match_id
    }
    game_id = Metr.create_game(game_input)

    {player_id, deck_id, match_id, game_id}
  end

  def cleanup_single_states({player_id, deck_id, match_id, game_id}) do
    game = Game.read(game_id)

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
    Data.wipe_test("Game", [game_id])
    Data.wipe_test("Result", game.results)
    Data.wipe_test("Match", match_id)

  end
end

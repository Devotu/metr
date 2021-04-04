ExUnit.start()

defmodule TestHelper do
  alias Metr.Data
  alias Metr.Event
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player

  def init_single_states(player_name, deck_name) do
    player_id = Metr.create_player(%{name: player_name})
    deck_id = Metr.create_deck(%{name: deck_name, player_id: player_id})
    match_id = Metr.create_match(%{
      player_1_id: player_id,
      deck_1_id: deck_id,
      player_2_id: player_id,
      deck_2_id: deck_id,
      ranking: false
    })
    game_id = Metr.create_game(%{
      deck_1: deck_id,
      deck_2: deck_id,
      player_1: player_id,
      player_2: player_id,
      winner: 2,
      match: match_id
    })

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

  def init_double_state(player_one_name, deck_one_name, player_two_name, deck_two_name) do
    player_one_id = Metr.create_player(%{name: player_one_name})
    deck_one_id = Metr.create_deck(%{name: deck_one_name, player_id: player_one_id})
    player_two_id = Metr.create_player(%{name: player_two_name})
    deck_two_id = Metr.create_deck(%{name: deck_two_name, player_id: player_two_id})

    match_id = Metr.create_match(%{
      player_1_id: player_one_id,
      deck_1_id: deck_one_id,
      player_2_id: player_two_id,
      deck_2_id: deck_two_id,
      ranking: false
    })
    game_id = Metr.create_game(%{
      deck_1: deck_one_id,
      deck_2: deck_two_id,
      player_1: player_one_id,
      player_2: player_two_id,
      winner: 2,
      match: match_id
    })

    {player_one_id, deck_one_id, match_id, game_id,
    player_two_id, deck_two_id, match_id, game_id}
  end

  def cleanup_double_states({player_one_id, deck_one_id, match_id, game_id, player_two_id, deck_two_id, match_id, game_id}) do
    game = Game.read(game_id)

    Data.wipe_test("Player", [player_one_id, player_two_id])
    Data.wipe_test("Deck", [deck_one_id, deck_two_id])
    Data.wipe_test("Game", [game_id])
    Data.wipe_test("Result", game.results)
    Data.wipe_test("Match", match_id)
  end
end

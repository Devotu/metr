ExUnit.start()

defmodule TestHelper do
  alias Metr.Data
  alias Metr.Modules.Game
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.MatchInput
  alias Metr.Modules.Input.PlayerInput

  def init_single_states(player_name, deck_name) do
    player_id = Metr.create_player(%PlayerInput{name: player_name})
    deck_id = Metr.create_deck(%DeckInput{name: deck_name, player_id: player_id, format: "standard"})

    match_id =
      Metr.create_match(%MatchInput{
        player_one: player_id,
        player_two: player_id,
        deck_one: deck_id,
        deck_two: deck_id,
        ranking: false
      })

    game_id =
      Metr.create_game(%GameInput{
        player_one: player_id,
        player_two: player_id,
        deck_one: deck_id,
        deck_two: deck_id,
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
    player_1_id = Metr.create_player(%PlayerInput{name: player_one_name})
    deck_1_id = Metr.create_deck(%DeckInput{name: deck_one_name, player_id: player_1_id, format: "standard"})
    player_2_id = Metr.create_player(%PlayerInput{name: player_two_name})
    deck_2_id = Metr.create_deck(%DeckInput{name: deck_two_name, player_id: player_2_id, format: "standard"})

    match_id =
      Metr.create_match(%MatchInput{
        player_one: player_1_id,
        player_two: player_2_id,
        deck_one: deck_1_id,
        deck_two: deck_2_id,
        ranking: false
      })

    game_id =
      Metr.create_game(%GameInput{
        player_one: player_1_id,
        player_two: player_2_id,
        deck_one: deck_1_id,
        deck_two: deck_2_id,
        winner: 2,
        match: match_id
      })

    {player_1_id, deck_1_id, player_2_id, deck_2_id, match_id, game_id}
  end

  def cleanup_double_states({player_1_id, deck_1_id, player_2_id, deck_2_id, match_id, game_id}) do
    game = Game.read(game_id)

    Data.wipe_test("Player", [player_1_id, player_2_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id])
    Data.wipe_test("Game", [game_id])
    Data.wipe_test("Result", game.results)
    Data.wipe_test("Match", match_id)
  end
end

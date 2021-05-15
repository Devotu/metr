ExUnit.start()

defmodule TestHelper do
  alias Metr.Data
  alias Metr.Modules.Game
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.MatchInput
  alias Metr.Modules.Input.PlayerInput

  def init_single_states(player_name, deck_name) do
    player_id = Metr.create(%PlayerInput{name: player_name}, :player)
    deck_id = Metr.create(%DeckInput{name: deck_name, player_id: player_id, format: "standard"}, :deck)

    match_id =
      Metr.create(%MatchInput{
        player_one: player_id,
        player_two: player_id,
        deck_one: deck_id,
        deck_two: deck_id,
        ranking: false
      }, :match)

    game_id =
      Metr.create(%GameInput{
        player_one: player_id,
        player_two: player_id,
        deck_one: deck_id,
        deck_two: deck_id,
        winner: 2,
        match: match_id
      }, :game)

    {player_id, deck_id, match_id, game_id}
  end

  def cleanup_single_states({player_id, deck_id, match_id, game_id}) do
    game = Game.read(game_id)

    Data.wipe_test(:player, [player_id])
    Data.wipe_test(:deck, [deck_id])
    Data.wipe_test(:game, [game_id])
    Data.wipe_test(:result, game.results)
    Data.wipe_test(:match, match_id)
  end

  def init_double_state(player_one_name, deck_one_name, player_two_name, deck_two_name) do
    player_1_id = Metr.create(%PlayerInput{name: player_one_name}, :player)
    deck_1_id = Metr.create(%DeckInput{name: deck_one_name, player_id: player_1_id, format: "standard"}, :deck)
    player_2_id = Metr.create(%PlayerInput{name: player_two_name}, :player)
    deck_2_id = Metr.create(%DeckInput{name: deck_two_name, player_id: player_2_id, format: "standard"}, :deck)

    match_id =
      Metr.create(%MatchInput{
        player_one: player_1_id,
        player_two: player_2_id,
        deck_one: deck_1_id,
        deck_two: deck_2_id,
        ranking: false
      }, :match)

    game_id =
      Metr.create(%GameInput{
        player_one: player_1_id,
        player_two: player_2_id,
        deck_one: deck_1_id,
        deck_two: deck_2_id,
        winner: 2,
        match: match_id
      }, :game)

    {player_1_id, deck_1_id, player_2_id, deck_2_id, match_id, game_id}
  end

  def cleanup_double_states({player_1_id, deck_1_id, player_2_id, deck_2_id, match_id, game_id}) do
    game = Game.read(game_id)

    Data.wipe_test(:player, [player_1_id, player_2_id])
    Data.wipe_test(:deck, [deck_1_id, deck_2_id])
    Data.wipe_test(:game, [game_id])
    Data.wipe_test(:result, game.results)
    Data.wipe_test(:match, match_id)
  end
end

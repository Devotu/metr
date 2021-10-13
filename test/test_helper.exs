ExUnit.start()

defmodule TestHelper do
  alias Metr.Data
  alias Metr.Modules.State
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.MatchInput
  alias Metr.Modules.Input.PlayerInput

  @propagation_delay 48

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
    game = State.read(game_id, :game)

    TestHelper.wipe_test(:player, [player_id])
    TestHelper.wipe_test(:deck, [deck_id])
    TestHelper.wipe_test(:game, [game_id])
    TestHelper.wipe_test(:result, game.results)
    TestHelper.wipe_test(:match, match_id)
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
    game = State.read(game_id, :game)

    TestHelper.wipe_test(:player, [player_1_id, player_2_id])
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id])
    TestHelper.wipe_test(:game, [game_id])
    TestHelper.wipe_test(:result, game.results)
    TestHelper.wipe_test(:match, match_id)
  end

  def wipe_test(module, ids) when is_list(ids) when is_atom(module) and is_list(ids)  do
    Enum.each(ids, fn id -> wipe_test(module, id) end)
  end

  def wipe_test(module, id) when is_atom(module) and is_bitstring(id)  do
    Data.wipe_state(id, module)
    wipe_log(module, id)
  end


  def wipe_log(module, ids)  when is_atom(module) and is_list(ids) do
    Enum.each(ids, fn id -> wipe_log(module, id) end)
  end

  def wipe_log(module, id) when is_atom(module) and is_bitstring(id)  do
    "data/event/#{Data.module_specific_id(module, id)}.log"
    |> File.rm()
  end

  def init_only_player(name) do
    Metr.create(%PlayerInput{name: name}, :player)
  end

  def init_only_deck(name, player_id, format \\ "standard") do
    Metr.create(%DeckInput{name: name, format: format, player_id: player_id}, :deck)
  end

  def delay() do
    :timer.sleep(@propagation_delay)
  end
end

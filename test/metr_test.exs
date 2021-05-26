defmodule MetrTest do
  use ExUnit.Case

  alias Metr.Event
  alias Metr.Data
  alias Metr.Modules.State
  alias Metr.Modules.Stately
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Player
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.MatchInput
  alias Metr.Modules.Input.PlayerInput
  alias Metr.Router
  alias Metr.Id

  @id_length 14

  test "list players" do
    assert is_list(Metr.list(:player))
  end

  test "create deck" do
    player_id = TestHelper.init_only_player "Martin Metr"
    format = "commander"
    price = 12.34
    # player_id = "martin_metr"

    deck_id = %DeckInput{
      black: false,
      white: false,
      red: true,
      green: false,
      blue: true,
      colorless: false,
      format: format,
      name: "Mike Metr",
      player_id: player_id,
      theme: "commanding",
      price: price
    }
    |> Metr.create(:deck)

    [read_event] = Deck.feed(Event.new([:read, :deck], %{deck_id: deck_id}), nil)
    deck = read_event.data.out
    assert false == deck.black
    assert false == deck.white
    assert true == deck.red
    assert false == deck.green
    assert true == deck.blue
    assert false == deck.colorless
    assert nil == deck.rank # can only be initialized with nil and then adjusted
    assert price == deck.price
    TestHelper.wipe_test(:deck, deck_id)
    TestHelper.wipe_test(:player, player_id)
  end

  test "list decks" do
    assert is_list(Metr.list(:deck))
  end

  test "list games" do
    assert is_list(Metr.list(:game))
  end

  test "list results" do
    assert is_list(Metr.list(:result))
  end

  test "create game" do
    player_1_id = TestHelper.init_only_player "David Metr"
    player_2_id = TestHelper.init_only_player "Erik Metr"
    deck_1_id = TestHelper.init_only_deck "Delta Metr", player_1_id
    deck_2_id = TestHelper.init_only_deck "Echo Metr", player_2_id

    game_1_id = %GameInput{
      player_one: player_1_id,
      player_two: player_2_id,
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      winner: 2
    }
    |> Metr.create(:game)

    # assert :ok == status
    assert @id_length = String.length(game_1_id)

    game_2 = %GameInput{
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      fun_one: 1,
      fun_two: -2,
      player_one: player_1_id,
      player_two: player_2_id,
      power_one: 2,
      power_two: -2,
      winner: 1
    }

    game_2_id = Metr.create(game_2, :game)
    assert @id_length = String.length(game_2_id)

    results = Metr.list(:result)

    assert 2 ==
             Enum.filter(results, fn r -> String.equivalent?(r.game_id, game_2_id) end)
             |> Enum.count()

    [deck_1] = Metr.list(:deck) |> Enum.filter(fn d -> String.equivalent?(d.id, deck_1_id) end)

    [player_2] =
      Metr.list(:player) |> Enum.filter(fn p -> String.equivalent?(p.id, player_2_id) end)

    assert 2 == Enum.count(deck_1.results)
    [_player_2_result_1, player_2_result_2] = player_2.results

    result_1 = Metr.read(player_2_result_2, :result)
    assert game_2_id == result_1.game_id
    assert player_2_id == result_1.player_id
    assert deck_2_id == result_1.deck_id
    assert 2 == result_1.place

    TestHelper.wipe_test(:player, [player_1_id, player_2_id])
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id])
    TestHelper.wipe_test(:game, [game_1_id, game_2_id])
    TestHelper.wipe_test(:result, deck_1.results)
    TestHelper.wipe_test(:result, player_2.results)
  end

  test "delete game" do
    player_1_id = TestHelper.init_only_player "Filip Metr"
    player_2_id = TestHelper.init_only_player "Gustav Metr"
    deck_1_id = TestHelper.init_only_deck "Foxtrot Metr", player_1_id
    deck_2_id = TestHelper.init_only_deck "Golf Metr", player_2_id

    game_id = %GameInput{
      player_one: player_1_id,
      player_two: player_2_id,
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      winner: 2
    }
    |> Metr.create(:game)

    game = Game.read(game_id)
    assert "Game #{game_id} deleted" == Metr.delete(game_id, :game)

    deck_1 = Metr.read(deck_1_id, :deck)
    assert 0 == Enum.count(deck_1.results)

    player_1 = Metr.read(player_1_id, :player)
    assert 0 == Enum.count(player_1.results)

    assert {:error, "Game not an actual game id not found"} ==
             Metr.delete("not an actual game id", :game)

    results = Metr.list(:result)

    assert 0 ==
             Enum.filter(results, fn g -> String.equivalent?(g.id, game_id) end) |> Enum.count()

    TestHelper.wipe_test(:player, [player_1_id, player_2_id])
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id])
    TestHelper.wipe_test(:game, [game_id])
    TestHelper.wipe_test(:result, game.results)
  end

  test "list results by deck" do
    player_1_id = TestHelper.init_only_player "Helge Metr"
    player_2_id = TestHelper.init_only_player "Ivar Metr"
    player_3_id = TestHelper.init_only_player "Johan Metr"
    deck_1_id = TestHelper.init_only_deck "Hotel Metr", player_1_id
    deck_2_id = TestHelper.init_only_deck "India Metr", player_2_id
    deck_3_id = TestHelper.init_only_deck "Juliet Metr", player_3_id

    # 1 vs 2
    game_1_id = %GameInput{
      player_one: player_1_id,
      player_two: player_2_id,
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      winner: 2
    }
    |> Metr.create(:game)

    # 1 vs 3
    game_2_id = %GameInput{
      player_one: player_1_id,
      player_two: player_3_id,
      deck_one: deck_1_id,
      deck_two: deck_3_id,
      winner: 1,
      power_one: 2,
      power_two: 2,
      fun_one: 1,
      fun_two: 2
    }
    |> Metr.create(:game)

    results =
      Metr.list(:result, by: {:game, game_1_id}) ++ Metr.list(:result, by: {:game, game_2_id})

    assert 4 == results |> Enum.count()
    assert 2 == Metr.list(:result, by: {:deck, deck_1_id}) |> Enum.count()
    assert 1 == Metr.list(:result, by: {:deck, deck_2_id}) |> Enum.count()

    TestHelper.wipe_test(:player, [player_1_id, player_2_id, player_3_id])
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id, deck_3_id])
    TestHelper.wipe_test(:game, [game_1_id, game_2_id])
    TestHelper.wipe_test(:result, Enum.map(results, fn r -> r.id end))
  end

  test "read log of x" do
    player_1_id = TestHelper.init_only_player "Kalle Metr"
    player_2_id = TestHelper.init_only_player "Ludvig Metr"
    deck_1_id = TestHelper.init_only_deck "Kilo Metr", player_1_id
    deck_2_id = TestHelper.init_only_deck "Lima Metr", player_2_id

    # 1 vs 2
    game_1_id = %GameInput{
      player_one: player_1_id,
      player_two: player_2_id,
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      winner: 2
    }
    |> Metr.create(:game)

    # 1 vs 3
    game_2_id = %GameInput{
      player_one: player_1_id,
      player_two: player_2_id,
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      winner: 1
    }
    |> Metr.create(:game)

    assert 3 == Metr.read_log(deck_1_id, :deck) |> Enum.count()
    assert 4 == Metr.read_log(player_1_id, :player) |> Enum.count()

    TestHelper.wipe_test(:player, [player_1_id, player_2_id])
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id])
    TestHelper.wipe_test(:game, [game_1_id, game_2_id])
  end

  test "format" do
    assert "standard" in Metr.list(:format)
    assert "pauper" in Metr.list(:format)
  end

  test "adjust rank" do
    player_id = TestHelper.init_only_player "Olof Metr"
    deck_id = TestHelper.init_only_deck "Oscar Metr", player_id

    deck_initial = Metr.read(deck_id, :deck)
    assert nil == deck_initial.rank

    # 01
    Metr.alter_rank(deck_id, :up)

    deck_0_1 = Metr.read(deck_id, :deck)
    assert {0, 1} == deck_0_1.rank

    # 10
    Metr.alter_rank(deck_id, :up)
    # 11
    Metr.alter_rank(deck_id, :up)
    # 20
    Metr.alter_rank(deck_id, :up)

    deck_2_0 = Metr.read(deck_id, :deck)
    assert {2, 0} == deck_2_0.rank

    # 2-1
    Metr.alter_rank(deck_id, :down)
    # 10
    Metr.alter_rank(deck_id, :down)
    # 1-1
    Metr.alter_rank(deck_id, :down)
    # 00
    Metr.alter_rank(deck_id, :down)
    # 0-1
    Metr.alter_rank(deck_id, :down)
    # -10
    Metr.alter_rank(deck_id, :down)
    # -1-1
    Metr.alter_rank(deck_id, :down)
    # -20
    Metr.alter_rank(deck_id, :down)

    deck_02_0 = Metr.read(deck_id, :deck)
    assert {-2, 0} == deck_02_0.rank

    TestHelper.wipe_test(:player, [player_id])
    TestHelper.wipe_test(:deck, [deck_id])
  end

  test "match lifecycle" do
    player_1_id = TestHelper.init_only_player "Petter Metr"
    player_2_id = TestHelper.init_only_player "Quintus Metr"
    deck_1_id = TestHelper.init_only_deck "Papa Metr", player_1_id
    deck_2_id = TestHelper.init_only_deck "Qubec Metr", player_2_id

    match_data = %MatchInput{
      player_one: player_1_id,
      player_two: player_2_id,
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      ranking: true
    }

    match_id = Metr.create(match_data, :match)

    initial_match = Metr.read(match_id, :match)
    assert [] == initial_match.games
    assert :initialized == initial_match.status
    assert player_1_id == initial_match.player_one
    assert deck_2_id == initial_match.deck_two

    game_data = %GameInput{
      player_one: player_1_id,
      player_two: player_2_id,
      deck_one: deck_1_id,
      deck_two: deck_2_id,
      winner: 2,
      match: match_id
    }

    game_1_id = Metr.create(game_data, :game)

    ongoing_match = Metr.read(match_id, :match)
    assert 1 = ongoing_match.games |> Enum.count()
    assert :open == ongoing_match.status
    assert nil == ongoing_match.winner

    game_2_id = Metr.create(Map.put(game_data, :winner, 1), :game)
    game_3_id = Metr.create(game_data, :game)

    assert :ok == Metr.end_match(match_id)

    ended_match = Metr.read(match_id, :match)
    assert 3 = ended_match.games |> Enum.count()
    assert true == ended_match.ranking
    assert :closed == ended_match.status
    assert 2 == ended_match.winner

    deck_1 = Metr.read(deck_1_id, :deck)
    assert {0, -1} == deck_1.rank
    deck_2 = Metr.read(deck_2_id, :deck)
    assert {0, 1} == deck_2.rank

    TestHelper.wipe_test(:player, [player_1_id, player_2_id])
    TestHelper.wipe_test(:deck, [deck_1_id, deck_2_id])
    TestHelper.wipe_test(:game, [game_1_id, game_2_id, game_3_id])
    TestHelper.wipe_test(:match, [match_id])
    TestHelper.wipe_test(:result, [deck_1.results])
  end

  test "list results by ids" do
    player_id = TestHelper.init_only_player "Rudolf Metr"
    deck_id = TestHelper.init_only_deck "Romeo Metr", player_id

    game = %GameInput{
      player_one: player_id,
      player_two: player_id,
      deck_one: deck_id,
      deck_two: deck_id,
      winner: 1
    }
    |> Metr.create(:game)
    |> Metr.read(:game)

    results = Metr.list(game.results, :result)
    assert 2 == Enum.count(results)
    first_result = List.first(results)
    assert deck_id == first_result.deck_id
    assert player_id == first_result.player_id

    TestHelper.wipe_test(:player, [player_id])
    TestHelper.wipe_test(:deck, deck_id)
    TestHelper.wipe_test(:game, game.id)
    TestHelper.wipe_test(:result, game.results)
  end

  test "read state of x" do
    player_1_id = TestHelper.init_only_player "Sigurd Metr"
    deck_1_id = TestHelper.init_only_deck "Sierra Metr", player_1_id

    game_1_id = %GameInput{
      player_one: player_1_id,
      player_two: player_1_id,
      deck_one: deck_1_id,
      deck_two: deck_1_id,
      winner: 2
    }
    |> Metr.create(:game)

    deck_1_state = Metr.read(deck_1_id, :deck)
    [result_1, result_2] = Metr.list(:result, by: {:game, game_1_id})
    assert [result_1.id, result_2.id] == deck_1_state.results

    player_1_state = Metr.read(player_1_id, :player)
    assert [result_1.id, result_2.id] == player_1_state.results

    game_1_state = Metr.read(game_1_id, :game)
    assert 2 == Enum.count(game_1_state.results)

    TestHelper.wipe_test(:player, [player_1_id])
    TestHelper.wipe_test(:deck, [deck_1_id])
    TestHelper.wipe_test(:game, [game_1_id])
  end

  test "rerun log of x" do
    player_name = "Tore Metr"
    deck_name = "Tango Metr"

    {player_id, deck_id, match_id, game_id} =
      TestHelper.init_single_states(player_name, deck_name)

    original_deck = Stately.read(deck_id, :deck)
    # To verify it is not the same state read
    Data.wipe_state([deck_id], :deck)
    assert {:error, "Deck #{deck_id} not found"} == Deck.read(deck_id)

    assert {:error, "not found"} == Data.recall_state(:deck, deck_id)

    assert :ok == Metr.rerun(:deck, deck_id)

    recreated_deck = Stately.read(deck_id, :deck)
    assert recreated_deck == original_deck

    TestHelper.cleanup_single_states({player_id, deck_id, match_id, game_id})
  end

  test "add tag t to x" do
    player_name = "Urban Metr"
    deck_name = "Uniform Metr"

    {player_id, deck_id, match_id, game_id} =
      TestHelper.init_single_states(player_name, deck_name)

    game = Game.read(game_id)

    tag_name = "test"
    original_deck = Stately.read(deck_id, :deck)
    assert [] == original_deck.tags
    assert tag_name == Metr.add_tag(tag_name, :deck, deck_id)

    tagged_deck = Stately.read(deck_id, :deck)
    assert [tag_name] == tagged_deck.tags

    assert is_struct(Metr.add_tag(tag_name, :player, player_id))
    tagged_player = Stately.read(player_id, :player)
    assert [tag_name] == tagged_player.tags

    assert is_struct(Metr.add_tag(tag_name, :match, match_id))
    tagged_match = Stately.read(match_id, :match)
    assert [tag_name] == tagged_match.tags

    assert is_struct(Metr.add_tag(tag_name, :game, game_id))
    tagged_game = Stately.read(game_id, :game)
    assert [tag_name] == tagged_game.tags

    result_id_1 = game.results |> List.first()
    assert is_struct(Metr.add_tag(tag_name, :result, result_id_1))
    tagged_result = Stately.read(result_id_1, :result)
    assert [tag_name] == tagged_result.tags

    test_tag = Metr.read(tag_name, :tag)
    [dt, pt, mt, gt, rt] = test_tag.tagged
    {did, _dtime} = dt
    assert did == deck_id
    {pid, _ptime} = pt
    assert pid == player_id
    {mid, _mtime} = mt
    assert mid == match_id
    {gid, _gtime} = gt
    assert gid == game_id
    {rid, _rtime} = rt
    assert rid == result_id_1

    assert [test_tag] == Metr.list(:tag)

    TestHelper.cleanup_single_states({player_id, deck_id, match_id, game_id})
    TestHelper.wipe_test(:tag, tag_name)
  end
end

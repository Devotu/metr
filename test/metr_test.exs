defmodule MetrTest do
  use ExUnit.Case

  alias Metr.Event
  alias Metr.Data
  alias Metr.Deck
  alias Metr.Player
  alias Metr.Router
  alias Metr.Id

  @id_length 14

  test "list players" do
    assert is_list Metr.list_players()
  end

  test "create deck" do
    Player.feed Event.new([:create, :player], %{name: "Martin Metr"}), nil
    format = "commander"
    deck_data = %{
      black: false,
      white: false,
      red: true,
      green: false,
      blue: true,
      colorless: false,
      format: format,
      name: "Mike Metr",
      player_id: "martin_metr",
      theme: "commanding",
      rank: -1,
      advantage: 1
    }
    deck_id = Metr.create_deck(deck_data)
    [read_event] = Deck.feed Event.new([:read, :deck], %{deck_id: deck_id}), nil
    deck = read_event.data.out
    assert false == deck.black
    assert false == deck.white
    assert true == deck.red
    assert false == deck.green
    assert true == deck.blue
    assert false == deck.colorless
    assert {-1,1} == deck.rank
    Data.wipe_test("Deck", deck_id)
    Data.wipe_test("Player", deck_data.player_id)
  end

  test "list decks" do
    assert is_list Metr.list_decks()
  end

  test "list games" do
    assert is_list Metr.list_games()
  end

  test "create game" do
    player_1_name = "David Metr"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Delta Metr"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Erik Metr"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "Echo Metr"
    deck_2_id = Id.hrid(deck_2_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil

    game_1 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_1_id = Metr.create_game(game_1)

    # assert :ok == status
    assert @id_length = String.length(game_1_id)

    game_2 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :fun_1 => 1,
      :fun_2 => -2,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :power_1 => 2,
      :power_2 => -2,
      :winner => 1}
    game_2_id = Metr.create_game(game_2)

    games = Metr.list_games()

    assert @id_length = String.length(game_2_id)

    assert 1 == Enum.filter(games, fn g -> String.equivalent?(g.id, game_2_id) end) |> Enum.count()

    [deck_1] = Metr.list_decks() |> Enum.filter(fn d -> String.equivalent?(d.id, deck_1_id) end)
    [player_2] = Metr.list_players() |> Enum.filter(fn p -> String.equivalent?(p.id, player_2_id) end)

    assert 2 == Enum.count(deck_1.games)
    assert 2 == Enum.count(player_2.games)

    Data.wipe_test("Player", [player_1_id, player_2_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id])
    Data.wipe_test("Game", [game_1_id, game_2_id])
  end


  test "delete game" do
    player_1_name = "Filip Metr"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Foxtrot Metr"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Gustav Metr"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "Golf Metr"
    deck_2_id = Id.hrid(deck_2_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil

    game = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_id = Metr.create_game(game)
    assert game_id == Metr.delete_game(game_id)

    deck_1 = Metr.read_deck(deck_1_id)
    assert 0 == Enum.count(deck_1.games)

    player_1 = Metr.read_player(player_1_id)
    assert 0 == Enum.count(player_1.games)

    assert :error == Metr.delete_game("not an actual game id")

    games = Metr.list_games()
    assert 0 == Enum.filter(games, fn g -> String.equivalent?(g.id, game_id) end) |> Enum.count()

    Data.wipe_test("Player", [player_1_id, player_2_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id])
    Data.wipe_test("Game", [game_id])
  end



  test "list games by deck" do
    player_1_name = "Helge Metr"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Hotel Metr"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Ivar Metr"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "India Metr"
    deck_2_id = Id.hrid(deck_2_name)

    player_3_name = "Johan Metr"
    player_3_id = Id.hrid(player_3_name)
    deck_3_name = "Juliett Metr"
    deck_3_id = Id.hrid(deck_3_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_3_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_3_name, player_id: player_3_id}), nil

    #1 vs 2
    game_1 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_1_id = Metr.create_game(game_1)


    #1 vs 3
    game_2 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_3_id,
      :fun_1 => 1,
      :fun_2 => -2,
      :player_1 => player_1_id,
      :player_2 => player_3_id,
      :power_1 => 2,
      :power_2 => -2,
      :winner => 1}
    game_2_id = Metr.create_game(game_2)

    assert 2 <= Enum.count(Metr.list_games())
    assert 2 == Enum.count(Metr.list_games(:deck, deck_1_id))
    assert 1 == Enum.count(Metr.list_games(:deck, deck_2_id))

    Data.wipe_test("Player", [player_1_id, player_2_id, player_3_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id, deck_3_id])
    Data.wipe_test("Game", [game_1_id, game_2_id])
  end


  test "read log of x" do
    player_1_name = "Kalle Metr"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Kilo Metr"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Ludvig Metr"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "Lima Metr"
    deck_2_id = Id.hrid(deck_2_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Router.input Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id})
    Router.input Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id})

    #1 vs 2
    game_1 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_1_id = Metr.create_game(game_1)

    #1 vs 3
    game_2 = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 1}
    game_2_id = Metr.create_game(game_2)


    deck_1_log = Metr.read_entity_log(:deck, deck_1_id)
    assert 3 == Enum.count(deck_1_log)

    player_1_log = Metr.read_entity_log(:player, player_1_id)
    assert 4 == Enum.count(player_1_log)

    Data.wipe_test("Player", [player_1_id, player_2_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id])
    Data.wipe_test("Game", [game_1_id, game_2_id])
  end


  test "format" do
    assert "standard" in Metr.list_formats()
    assert "pauper" in Metr.list_formats()
  end


  test "adjust rank" do
    player_name = "Olof Metr"
    player_id = Id.hrid(player_name)
    deck_name = "Oscar Metr"
    deck_id = Id.hrid(deck_name)

    Player.feed Event.new([:create, :player], %{name: player_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_name, player_id: player_id}), nil

    deck_initial = Metr.read_deck(deck_id)
    assert nil == deck_initial.rank

    Metr.alter_rank(deck_id, :up) #01

    deck_0_1 = Metr.read_deck(deck_id)
    assert {0,1} == deck_0_1.rank

    Metr.alter_rank(deck_id, :up) #10
    Metr.alter_rank(deck_id, :up) #11
    Metr.alter_rank(deck_id, :up) #20

    deck_2_0 = Metr.read_deck(deck_id)
    assert {2,0} == deck_2_0.rank

    Metr.alter_rank(deck_id, :down) #2-1
    Metr.alter_rank(deck_id, :down) #10
    Metr.alter_rank(deck_id, :down) #1-1
    Metr.alter_rank(deck_id, :down) #00
    Metr.alter_rank(deck_id, :down) #0-1
    Metr.alter_rank(deck_id, :down) #-10
    Metr.alter_rank(deck_id, :down) #-1-1
    Metr.alter_rank(deck_id, :down) #-20

    deck_02_0 = Metr.read_deck(deck_id)
    assert {-2,0} == deck_02_0.rank

    Data.wipe_test("Player", [player_id])
    Data.wipe_test("Deck", [deck_id])
  end



  test "create match" do
    player_1_name = "Petter Metr"
    player_1_id = Id.hrid(player_1_name)
    deck_1_name = "Papa Metr"
    deck_1_id = Id.hrid(deck_1_name)

    player_2_name = "Quintus Metr"
    player_2_id = Id.hrid(player_2_name)
    deck_2_name = "Qubec Metr"
    deck_2_id = Id.hrid(deck_2_name)

    Player.feed Event.new([:create, :player], %{name: player_1_name}), nil
    Player.feed Event.new([:create, :player], %{name: player_2_name}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_1_name, player_id: player_1_id}), nil
    Deck.feed Event.new([:create, :deck], %{name: deck_2_name, player_id: player_2_id}), nil

    match_data = %{
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id}
    match_id = Metr.create_match(match_data)

    initial_match = Metr.read_match(match_id)
    IO.inspect(initial_match, label: "metr test - initial")
    assert [] == initial_match.games
    assert :initialized == initial_match.status
    assert player_1_id == initial_match.player_one
    assert deck_2_id == initial_match.deck_two

    game_data = %{
      :match => match_id,
      :deck_1 => deck_1_id,
      :deck_2 => deck_2_id,
      :player_1 => player_1_id,
      :player_2 => player_2_id,
      :winner => 2}
    game_1_id = Metr.create_game(game_data)

    ongoing_match = Metr.read_match(match_id)
    IO.inspect(ongoing_match, label: "metr test - ongoing")
    assert 1 = ongoing_match.games |> Enum.count()
    assert :open == ongoing_match.status

    game_2_id = Metr.create_game(Map.put(game_data, :winner, 1))
    game_3_id = Metr.create_game(game_data)

    assert :ok == Metr.end_match(match_id, :true)

    ended_match = Metr.read_match(match_id)
    assert 3 = ended_match.games |> Enum.count()
    assert :true == ended_match.ranking
    assert :closed == ended_match.ranking

    deck_1 = Metr.read_deck(deck_1_id)
    assert {0,-1} == deck_1.rank
    deck_2 = Metr.read_deck(deck_2_id)
    assert {0,1} == deck_2.rank

    Data.wipe_test("Player", [player_1_id, player_2_id])
    Data.wipe_test("Deck", [deck_1_id, deck_2_id])
    Data.wipe_test("Game", [game_1_id, game_2_id, game_3_id])
    Data.wipe_test("Match", [match_id])
  end
end

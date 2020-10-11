defmodule Metr do

  alias Metr.Event
  alias Metr.Router

  @default_game %{
    :fun_1 => nil, :fun_2 => nil,
    :power_1 => nil, :power_2 => nil,
    :winner => 0, rank: false, match: nil
    }

  ## api
  def list_players() do
    list(:player)
  end

  def list_decks() do
    list(:deck)
  end

  def list_games(type, id) when is_atom(type) do
    constraints = Map.put(%{}, type_id(type), id)
    list(:game, constraints)
  end

  def list_games(limit) when is_number(limit) do
    constraints = Map.put(%{}, :limit, limit)
    list(:game, constraints)
  end

  def list_games() do
    list(:game)
  end


  def list_formats() do
    list(:format)
  end


  def read_player(id) do
    read(:player, id)
  end

  def read_deck(id) do
    read(:deck, id)
  end

  def read_game(id) do
    read(:game, id)
  end

  def read_match(id) do
    read(:match, id)
  end

  def read_entity_log(type, id) when is_atom(type) do
    read_log(type, id)
  end


  def create_game(%{
    :deck_1 => d1, :deck_2 => d2,
    :fun_1 => f1, :fun_2 => f2,
    :player_1 => p1, :player_2 => p2,
    :power_1 => s1, :power_2 => s2,
    :winner => w, rank: r, match: m
  }) do

    data = %{
      winner: w,
      rank: r,
      match: m,
      parts: [
        %{part: 1, details: %{deck_id: d1, player_id: p1, power: s1, fun: f1}},
        %{part: 2, details: %{deck_id: d2, player_id: p2, power: s2, fun: f2}},
      ]
    }

    create(:game, data)
  end

  def create_game(game_data) when is_map(game_data) do
    Map.merge(@default_game, game_data)
    |> create_game()
  end


  def delete_game(game_id) do
    #Start listener
    listening_task = Task.async(&listen/0)

    #Fire ze missiles
    Event.new([:delete, :game], %{game_id: game_id})
    |> Router.input(listening_task.pid)

    #Await response
    Task.await(listening_task)
  end


  def create_player(%{name: _n} = data) do
    create(:player, data)
  end


  def create_deck(%{rank: r, advantage: a} = data) do
    data
    |> Map.delete(:advantage)
    |> Map.put(:rank, {r, a})
    |> create_deck()
  end

  def create_deck(%{name: _n, player_id: _p} = data) do
    create(:deck, data)
  end


  def alter_rank(deck_id, :up) do
    Event.new([:alter, :rank], %{deck_id: deck_id, change: 1})
    |> run()
  end

  def alter_rank(deck_id, :down) do
    Event.new([:alter, :rank], %{deck_id: deck_id, change: -1})
    |> run()
  end


  def create_match(%{:deck_1 => _deck_1_id, :deck_2 => _deck_2_id, :player_1 => _player_1_id, :player_2 => _player_2_id} = data) do
    create(:match, data)
  end

  def end_match(match_id, ranking \\ :false) do
    Event.new([:end, :match], %{match_id: match_id, ranking: ranking})
    |> run()
  end



  ## private
  defp list(type) when is_atom(type) do
    #Start listener
    listening_task = Task.async(&listen/0)

    #Fire ze missiles
    Event.new([:list, type])
    |> Router.input(listening_task.pid)

    #Await response
    Task.await(listening_task)
  end

  defp list(type, constraints) when is_map(constraints) do
    #Start listener
    listening_task = Task.async(&listen/0)

    #Fire ze missiles
    Event.new([:list, type], constraints)
    |> Router.input(listening_task.pid)

    #Await response
    Task.await(listening_task)
  end


  defp create(type, data) when is_atom(type) do
    #Start listener
    listening_task = Task.async(&listen/0)

    #Fire ze missiles
    Event.new([:create, type], data)
    |> Router.input(listening_task.pid)

    #Await response
    Task.await(listening_task)
  end


  defp read(type, id) when is_atom(type) do
    #Start listener
    listening_task = Task.async(&listen/0)

    data = Map.put(%{}, type_id(type), id)

    #Fire ze missiles
    Event.new([:read, type], data)
    |> Router.input(listening_task.pid)

    #Await response
    Task.await(listening_task)
  end


  defp read_log(type, id) when is_atom(type) do
    #Start listener
    listening_task = Task.async(&listen/0)

    data = Map.put(%{}, type_id(type), id)

    #Fire ze missiles
    Event.new([:read, :log, type], data)
    |> Router.input(listening_task.pid)

    #Await response
    Task.await(listening_task)
  end


  defp run(%Event{} = event) do
    #Start listener
    listening_task = Task.async(&listen/0)

    #Fire ze missiles
    Router.input(event, listening_task.pid)

    #Await response
    Task.await(listening_task)
  end


  defp listen() do
    receive do
      {:error, msg} ->
        IO.puts("!! Error -- #{msg} !!")
        {:error, msg}
      msg ->
        msg
    end
  end


  defp type_id(type) when is_atom(type) do
    case type do
      :player -> :player_id
      :deck -> :deck_id
      :game -> :game_id
      :match -> :match_id
    end
  end


  def type_from_string(type) when is_bitstring(type) do
    case type do
      "player" -> :player
      "Player" -> :player
      "deck" -> :deck
      "Deck" -> :deck
      "game" -> :game
      "Game" -> :game
      "match" -> :match
      "Match" -> :match
    end
  end



  ## feed
  #by type
  def feed(%Event{tags: [type, response_pid]} = event, _orepp) when is_atom(type) and is_pid(response_pid) do
    send response_pid, event.data[type]
    []
  end

  #by id
  def feed(%Event{tags: [type, _status, response_pid], data: %{out: out}}, _orepp) when is_atom(type) and is_pid(response_pid) do
    send response_pid, out
    []
  end

  def feed(%Event{tags: [type, :log, _status, response_pid], data: %{out: out}}, _orepp) when is_atom(type) and is_pid(response_pid) do
    send response_pid, out
    []
  end

  def feed(%Event{tags: [type, :error, response_pid], data: data}, _orepp) when is_atom(type) and is_pid(response_pid) do
    send response_pid, {:error, data.msg}
    []
  end

  def feed(%Event{tags: [type, _status, response_pid]} = event, _orepp) when is_atom(type) and is_pid(response_pid) do
    send response_pid, event.data.id
    []
  end

  #by id failure
  def feed(%Event{tags: [type, :not, _status, response_pid]}, _orepp) when is_atom(type) and is_pid(response_pid) do
    send response_pid, :error
    []
  end

  def feed(_event, _orepp) do
    []
  end
end

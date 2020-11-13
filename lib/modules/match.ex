defmodule Metr.Match do
  defstruct id: "", games: [], player_one: "", player_two: "", deck_one: "", deck_two: "", ranking: false, status: nil, winner: nil

  use GenServer

  alias Metr.Data
  alias Metr.Deck
  alias Metr.Event
  alias Metr.Game
  alias Metr.Id
  alias Metr.Match
  alias Metr.Player
  alias Metr.Result


  ## feed
  def feed(%Event{id: _event_id, tags: [:create, :match], data: data} = event, repp) do
    case verify_input_data(data) do
      {:error, error} ->
        #Return
        [Event.new([:match, :create, :fail], %{cause: error, data: data})]
      {:ok} ->
        id = Id.guid()
        process_name = Data.genserver_id(__ENV__.module, id)
        #Start genserver
        case GenServer.start(Match, {id, data, event}, [name: process_name]) do
          {:ok, _pid} -> [Event.new(
            [:match, :created, repp],
            %{id: id, player_ids: [data.player_1_id, data.player_2_id], deck_ids: [data.deck_1_id, data.deck_2_id]}
            )]
          {:error, error} -> [Event.new([:match, :not, :created, repp], %{errors: [error]})]
        end
    end
  end

  def feed(%Event{id: _event_id, tags: [:end, :match], data: %{match_id: id}} = event, repp) do
    current_state = recall(id)
    rank_events = collect_rank_alterations(current_state)
    error_events = Event.only_errors(rank_events) #If any contains errors don't alter state
    #Return
    case Enum.count(error_events) > 0 do
      true ->
        error_events
        |> Enum.map(fn e -> Event.add_repp(e, repp) end)
      false ->
        close(id, event.tags, event.data, event, repp) ++ rank_events
    end
  end

  def feed(%Event{id: _event_id, tags: [:read, :match] = tags, data: %{match_id: id}}, repp) do
    ready_process(id)
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags})
    [Event.new([:match, :read, repp], %{out: msg})]
  end

  def feed(%Event{id: _event_id, tags: [:read, :log, :match], data: %{match_id: id}}, repp) do
    events = Data.read_log_by_id("Match", id)
    [Event.new([:match, :log, :read, repp], %{out: events})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :match], data: %{ids: ids}}, repp) when is_list(ids) do
    matches = Enum.map(ids, &recall/1)
    [Event.new([:matches, repp], %{matches: matches})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :match]}, repp) do
    matches = Data.list_ids(__ENV__.module)
    |> Enum.map(&recall/1)
    [Event.new([:matches, repp], %{matches: matches})]
  end

  def feed(%Event{id: _event_id, tags: [:game, :created, _orepp], data: %{id: _game_id, match_id: nil}}, _repp) do
    []
  end

  def feed(%Event{id: _event_id, tags: [:game, :created, _orepp], data: %{id: _game_id, match_id: id}} = event, _repp) do
    update(id, event.tags, event.data, event)
  end

  def feed(_event, _orepp) do
    []
  end


  defp ready_process(id) do
    # Is running?
    case {GenServer.whereis(Data.genserver_id(__ENV__.module, id)), Data.state_exists?(__ENV__.module, id)} do
      {nil, true} ->
        #Get state
        current_state = Map.merge(%Match{}, Data.recall_state(__ENV__.module, id))
        #Start process
        GenServer.start(Match, current_state, [name: Data.genserver_id(__ENV__.module, id)])
      {nil, false} ->
        {:error, :no_such_id}
      _ ->
        {:ok}
    end
  end


  defp recall(id) do
    ready_process(id)
    GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: [:read, :match]})
  end

  defp update(id, tags, data, event) do
    ready_process(id)
    #Call update
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags, data: data, event: event})
    #Return
    [Event.new([:match, :altered], %{out: msg})]
  end


  defp close(id, tags, data, event, repp) do
    ready_process(id)
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags, data: data, event: event})
    [Event.new([:match, :ended, repp], %{out: msg})]
  end


  defp verify_input_data(%{deck_1_id: deck_1_id, deck_2_id: deck_2_id, player_1_id: player_1_id, player_2_id: player_2_id, ranking: ranking}) do
    {:ok}
    |> verify_player(player_1_id)
    |> verify_player(player_2_id)
    |> verify_deck(deck_1_id)
    |> verify_deck(deck_2_id)
    |> verify_rank(deck_1_id, deck_2_id, ranking)
  end


  defp verify_player({:error, _cause} = error, _id), do: error
  defp verify_player({:ok}, id) do
    case get_player(id) do
      nil ->  {:error, "player #{id} not found"}
      _ ->    {:ok}
    end
  end

  defp verify_deck({:error, _cause} = error, _id), do: error
  defp verify_deck({:ok}, id) do
    case get_deck(id) do
      nil ->  {:error, "deck #{id} not found"}
      _ ->    {:ok}
    end
  end

  defp verify_rank({:error, _cause} = error, _deck_id_1, _deck_id_2, _ranking), do: error
  defp verify_rank({:ok}, _deck_id_1, _deck_id_2, :false), do: {:ok}
  defp verify_rank({:ok}, deck_id_1, deck_id_2, :true) do
    deck_1 = get_deck(deck_id_1)
    deck_2 = get_deck(deck_id_2)

    case deck_1.rank == deck_2.rank do
      false ->  {:error, "ranks does not match"}
      _ ->      {:ok}
    end
  end


  defp collect_rank_alterations(%Match{ranking: false}), do: []
  defp collect_rank_alterations(%Match{ranking: true} = state) do
    deck_1 = get_deck(state.deck_one)
    deck_2 = get_deck(state.deck_two)

    case deck_1.rank == deck_2.rank do
      true ->
        rank_decks(state, deck_1.id, deck_2.id)
      false ->
        [Event.new([:match, :error], %{msg: "ranks does not match"})]
    end
  end

  defp get_deck(deck_id) do
    Event.new([:read, :deck], %{deck_id: deck_id})
      |> Deck.feed(nil)
      |> Enum.map(&(&1.data.out))
      |> List.first()
  end

  defp get_game(game_id) do
    Event.new([:read, :game], %{game_id: game_id})
      |> Game.feed(nil)
      |> Enum.map(&(&1.data.out))
      |> List.first()
  end

  defp get_player(player_id) do
    Event.new([:read, :player], %{player_id: player_id})
      |> Player.feed(nil)
      |> Enum.map(&(&1.data.out))
      |> List.first()
  end


  defp rank_decks(state, deck_1_id, deck_2_id) do
    case find_winner(state) do
      0 -> []
      1 -> [new_rank_event(deck_1_id, 1), new_rank_event(deck_2_id, -1)]
      2 -> [new_rank_event(deck_1_id, -1), new_rank_event(deck_2_id, 1)]
    end
  end


  defp extract_wins(game) do
    game.results
      |> Enum.map(fn rid -> Result.read(rid) end)
      |> Enum.map(fn r -> {r.deck_id, r.place == 1} end)
  end


  defp collect_wins(results) do
    Enum.reduce(results, %{}, fn {deck_id, win?}, acc -> add_win(acc, deck_id, win?) end)
  end


  defp add_win(acc, _deck_id, false), do: acc
  defp add_win(acc, deck_id, true) do
    Map.update(acc, deck_id, 1, &(&1 + 1))
  end


  defp new_rank_event(deck_id, change) do
    Event.new([:alter, :rank], %{deck_id: deck_id, change: change})
  end


  defp find_winner(state) do
    tally = state.games
    |> Enum.map(fn gid -> get_game(gid) end)
    |> Enum.map(fn g -> extract_wins(g) end)
    |> Enum.concat()
    |> collect_wins()

    case tally[state.deck_one] - tally[state.deck_two] do
      0 -> 0
      x when x > 0 -> 1
      x when x < 0 -> 2
    end
  end


  ## gen
  @impl true

  def init({id, data, event}) do
    data = Map.put_new(data, :status, :initialized)
    state = %Match{
      id: id,
      player_one: data.player_1_id,
      player_two: data.player_2_id,
      deck_one: data.deck_1_id,
      deck_two: data.deck_2_id,
      ranking: data.ranking,
      status: :initialized
    }
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:ok, state}
  end

  def init(recalled_state) do
    {:ok, recalled_state}
  end


  @impl true
  def handle_call(%{tags: [:read, :match]}, _from, state) do
    #Reply
    {:reply, state, state}
  end

  @impl true
  def handle_call(%{tags: [:end, :match], data: %{match_id: id}, event: event}, _from, state) do
    new_state = state
      |> Map.put(:winner, find_winner(state))
      |> Map.put(:status, :closed)
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    #Reply
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(%{tags: [:game, :created, _orepp], data: %{id: game_id, match_id: id}, event: event}, _from, state) do
    new_state = state
      |> Map.update!(:games, &(&1 ++ [game_id]))
      |> Map.put(:status, :open)
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    #Reply
    {:reply, "Game #{game_id} added to match #{id}", new_state}
  end
end

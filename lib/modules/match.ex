defmodule Metr.Modules.Match do
  defstruct id: "",
            games: [],
            player_one: "",
            player_two: "",
            deck_one: "",
            deck_two: "",
            ranking: false,
            status: nil,
            winner: nil,
            time: 0,
            tags: []

  use GenServer

  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.Stately
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Time

  @name __ENV__.module |> Stately.module_to_name()

  ## feed
  def feed(%Event{id: _event_id, keys: [:create, :match], data: data} = event, repp) do
    case verify_input_data(data) do
      {:error, error} ->
        # Return
        [Event.new([:match, :error, repp], %{cause: error, data: data})]

      {:ok} ->
        id = Id.guid()
        process_name = Data.genserver_id(__ENV__.module, id)
        # Start genserver
        case GenServer.start(Match, {id, data, event}, name: process_name) do
          {:ok, _pid} ->
            [
              Event.new(
                [:match, :created, repp],
                %{
                  id: id,
                  player_ids: [data.player_1_id, data.player_2_id],
                  deck_ids: [data.deck_1_id, data.deck_2_id]
                }
              )
            ]

          {:error, error} ->
            [Event.new([:match, :not, :created, repp], %{errors: [error]})]
        end
    end
  end

  def feed(%Event{id: _event_id, keys: [:end, :match], data: %{match_id: id}} = event, repp) do
    current_state = read(id)
    rank_events = collect_rank_alterations(current_state)
    # If any contains errors don't alter state
    error_events = Event.only_errors(rank_events)
    # Return
    case Enum.count(error_events) > 0 do
      true ->
        error_events
        |> Enum.map(fn e -> Event.add_repp(e, repp) end)

      false ->
        close(id, event.keys, event.data, event, repp) ++ rank_events
    end
  end

  def feed(%Event{id: _event_id, keys: [:read, :match], data: %{match_id: id}}, repp) do
    match = read(id)
    [Event.new([:match, :read, repp], %{out: match})]
  end

  def feed(%Event{id: _event_id, keys: [:read, :log, :match], data: %{match_id: id}}, repp) do
    events = Data.read_log_by_id(id, "Match")
    [Event.new([:match, :log, :read, repp], %{out: events})]
  end

  def feed(%Event{id: _event_id, keys: [:list, :match], data: %{ids: ids}}, repp)
      when is_list(ids) do
    matches = Enum.map(ids, &read/1)
    [Event.new([:matches, repp], %{matches: matches})]
  end

  def feed(
        %Event{
          id: _event_id,
          keys: [:game, :created, _orepp],
          data: %{id: _game_id, match_id: nil}
        },
        _repp
      ) do
    []
  end

  def feed(
        %Event{
          id: _event_id,
          keys: [:game, :created, _orepp],
          data: %{id: _game_id, match_id: id}
        } = event,
        repp
      ) do
    [
      Stately.update(id, @name, event.keys, event.data, event)
      |> Stately.out_to_event(@name, [:altered, repp])
    ]
  end

  def feed(_event, _orepp) do
    []
  end

  ## module
  def read(id) do
    Stately.read(id, @name)
  end

  def exist?(id) do
    Stately.exist?(id, @name)
  end

  def module_name() do
    @name
  end

  ## private
  defp close(id, keys, data, event, repp) do
    Stately.ready(id, @name)

    msg =
      GenServer.call(Data.genserver_id(__ENV__.module, id), %{
        keys: keys,
        data: data,
        event: event
      })

    [Event.new([:match, :ended, repp], %{out: msg})]
  end

  defp verify_input_data(%{
         deck_1_id: deck_1_id,
         deck_2_id: deck_2_id,
         player_1_id: player_1_id,
         player_2_id: player_2_id,
         ranking: ranking
       }) do
    {:ok}
    |> verify_player(player_1_id)
    |> verify_player(player_2_id)
    |> verify_deck(deck_1_id)
    |> verify_deck(deck_2_id)
    |> verify_rank(deck_1_id, deck_2_id, ranking)
  end

  defp verify_player({:error, _cause} = error, _id), do: error

  defp verify_player({:ok}, id) do
    case Player.read(id) do
      nil -> {:error, "player #{id} not found"}
      {:error, reason} -> {:error, reason}
      _ -> {:ok}
    end
  end

  defp verify_deck({:error, _cause} = error, _id), do: error

  defp verify_deck({:ok}, id) do
    case Deck.read(id) do
      nil -> {:error, "deck #{id} not found"}
      {:error, reason} -> {:error, reason}
      _ -> {:ok}
    end
  end

  defp verify_rank({:error, _cause} = error, _deck_id_1, _deck_id_2, _ranking), do: error
  defp verify_rank({:ok}, _deck_id_1, _deck_id_2, false), do: {:ok}

  defp verify_rank({:ok}, deck_id_1, deck_id_2, true) do
    deck_1 = Deck.read(deck_id_1)
    deck_2 = Deck.read(deck_id_2)

    case deck_1.rank == deck_2.rank do
      false -> {:error, "ranks does not match"}
      _ -> {:ok}
    end
  end

  defp collect_rank_alterations(%Match{ranking: false}), do: []

  defp collect_rank_alterations(%Match{ranking: true} = state) do
    deck_1 = Deck.read(state.deck_one)
    deck_2 = Deck.read(state.deck_two)

    case deck_1.rank == deck_2.rank do
      true ->
        rank_decks(state)

      false ->
        [Event.new([:match, :error], %{msg: "ranks does not match"})]
    end
  end

  defp rank_decks(state) do
    case find_winner(state) do
      0 -> []
      1 -> [new_rank_event(state.deck_one, 1), new_rank_event(state.deck_two, -1)]
      2 -> [new_rank_event(state.deck_one, -1), new_rank_event(state.deck_two, 1)]
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
    tally =
      state.games
      |> Enum.map(fn gid -> Game.read(gid) end)
      |> Enum.map(fn g -> extract_wins(g) end)
      |> Enum.concat()
      |> collect_wins()

    find_winner(tally[state.deck_one], tally[state.deck_two])
  end

  defp find_winner(nil, nil), do: 0
  defp find_winner(w1, nil) when w1 > 0, do: 1
  defp find_winner(nil, w2) when w2 > 0, do: 2
  defp find_winner(w1, w2) when w1 > w2, do: 1
  defp find_winner(w1, w2) when w2 > w1, do: 2

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
      status: :initialized,
      time: Time.timestamp()
    }

    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:ok, state}
  end

  def init(recalled_state) do
    {:ok, recalled_state}
  end

  @impl true
  def handle_call(%{keys: [:read, :match]}, _from, state) do
    # Reply
    {:reply, state, state}
  end

  @impl true
  def handle_call(%{keys: [:end, :match], data: %{match_id: id}, event: event}, _from, state) do
    new_state =
      state
      |> Map.put(:winner, find_winner(state))
      |> Map.put(:status, :closed)

    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    # Reply
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:game, :created, _orepp], data: %{id: game_id, match_id: id}, event: event},
        _from,
        state
      ) do
    new_state =
      state
      |> Map.update!(:games, &(&1 ++ [game_id]))
      |> Map.put(:status, :open)

    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    # Reply
    {:reply, "Game #{game_id} added to match #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:tagged], data: %{id: id, tag: tag}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "#{@name} #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

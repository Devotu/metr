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
  alias Metr.Modules.State
  alias Metr.Modules.Match
  alias Metr.Modules.Result
  alias Metr.Modules.Input.MatchInput
  alias Metr.Rank
  alias Metr.Router
  alias Metr.Time

  @atom :match

  def feed(
    %Event{
      keys: [:create, @atom],
      data: %{id: id, input: _input}
      } = event,
    repp
  ) do

    State.create(id, @atom, event, repp)
  end

  ## feed
  def feed(
        %Event{
          keys: [:game, :created, _orepp],
          data: %{out: game_id}
        } = event,
        repp
      ) do

    game = State.read(game_id, :game)

    case game.match do
      nil ->
        []
      _ ->
        [
          State.update(game.match, @atom, event)
          |> Event.message_to_event([@atom, :altered, repp])
        ]
    end
  end

  def feed(
        %Event{
          keys: [:end, :match],
          data: %{id: id}
        } = event,
        repp
      ) do

    [
      State.update(id, @atom, event)
      |> Event.message_to_event([@atom, :altered, repp])
    ]
  end

  def feed(event, _orepp) do
    []
  end

  defp verify_input_data(%MatchInput{} = data) do
    p1 = verify_player(data.player_one)
    p2 = verify_player(data.player_two)
    d1 = verify_deck(data.deck_one)
    d2 = verify_deck(data.deck_two)
    r = verify_rank(data.deck_one, data.deck_two, data.ranking)

    case [p1, p2, d1, d2, r] do
      [{:error, e}, _, _, _, _] -> {:error, e}
      [_, {:error, e}, _, _, _] -> {:error, e}
      [_, _, {:error, e}, _, _] -> {:error, e}
      [_, _, _, {:error, e}, _] -> {:error, e}
      [_, _, _, _, {:error, e}] -> {:error, e}
      _ -> {:ok}
    end
  end

  defp verify_player(player_id) do
    case State.exist?(player_id, :player) do
      true -> {:ok}
      false -> {:error, "player #{player_id} not found"}
    end
  end

  defp verify_deck(deck_id) do
    case State.exist?(deck_id, :deck) do
      true -> {:ok}
      false -> {:error, "deck #{deck_id} not found"}
    end
  end

  defp verify_rank(_deck_id_1, _deck_id_2, false), do: {:ok}
  defp verify_rank(deck_id_1, deck_id_2, true) do
    deck_1 = State.read(deck_id_1, :deck)
    deck_2 = State.read(deck_id_2, :deck)

    case Rank.is_at_same(deck_1.rank, deck_2.rank) do
      false -> {:error, "ranks does not match"}
      _ -> {:ok}
    end
  end

  defp collect_rank_alterations(%Match{ranking: false}), do: []
  defp collect_rank_alterations(%Match{ranking: true} = state) do
    deck_1 = State.read(state.deck_one, :deck)
    deck_2 = State.read(state.deck_two, :deck)

    case Rank.is_at_same(deck_1.rank, deck_2.rank) do
      true ->
        rank_decks(state)
      false ->
        [Event.new([:match, :error], %{cause: "ranks does not match"})]
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
    Event.new([:alter, :rank], %{id: deck_id, change: change})
  end

  defp find_winner(state) do
    tally =
      state.games
      |> Enum.map(fn gid -> State.read(gid, :game) end)
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
  def init(%Event{} = event) do
    id = event.data.id
    input = event.data.input
    case verify_input_data(input) do
      {:error, e} ->
        {:stop, e}
      {:ok} ->
        state = %Match{
          id: id,
          player_one: input.player_one,
          player_two: input.player_two,
          deck_one: input.deck_one,
          deck_two: input.deck_two,
          ranking: input.ranking,
          status: :initialized,
          time: Time.timestamp()
        }

        case Data.save_state_with_log(@atom, id, state, event) do
          {:error, e} ->
            {:stop, e}
          _ ->
            {:ok, state}
        end
    end
  end

  def init(%Match{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, @atom]}, _from, state) do
    # Reply
    {:reply, state, state}
  end

  @impl true
  def handle_call(
        %Event{keys: [:end, :match]} = event,
        _from,
        state
      ) do

    state
    |> collect_rank_alterations()
    |> Router.input()

    new_state =
      state
      |> Map.put(:winner, find_winner(state))
      |> Map.put(:status, :closed)

    case Data.save_state_with_log(@atom, event.data.id, new_state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:reply, "Match #{state.id} ended", new_state}
    end
  end

  @impl true
  def handle_call(
        %Event{keys: [:game, :created, _orepp]} = event,
        _from,
        state
      ) do

    new_state = state
      |> Map.update!(:games, &(&1 ++ [event.data.out]))
      |> Map.put(:status, :open)

    case Data.save_state_with_log(@atom, state.id, state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:reply, "Game #{event.data.out} added to match #{state.id}", new_state}
    end
  end

  @impl true
  def handle_call(
        %Event{keys: [@atom, :tagged], data: %{id: id, tag: tag} = event},
        _from,
        state
      ) do

    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    case Data.save_state_with_log(@atom, id, new_state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, new_state}
    end
    {:reply, "Match #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

defmodule Metr.Modules.Player do
  defstruct id: "", name: "", decks: [], results: [], matches: [], time: 0, tags: []

  use GenServer

  alias Metr.Modules.State
  alias Metr.Modules.Stately
  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Input.PlayerInput
  alias Metr.Util
  alias Metr.Time

  @atom :player

  def feed(
        %Event{
          keys: [:deck, :created, _orepp],
          data: %{out: deck_id}
        } = event,
        repp
      ) do

    deck = State.read(deck_id, :deck)

    [
      State.update(deck.player, @atom, event)
      |> Event.message_to_event([@atom, :altered, repp])
    ]
  end

  def feed(
        %Event{
          id: _event_id,
          keys: [:game, :deleted, _orepp] = keys,
          data: %{results: result_ids}
        } = event,
        repp
      ) do
    # for each player find connections to this game
    player_result_ids =
      Data.list_ids(@atom)
      |> Enum.map(fn id -> read(id) end)
      |> Enum.filter(fn p -> Util.has_member?(p.results, result_ids) end)
      |> Enum.map(fn p -> {p.id, Util.find_first_common_member(p.results, result_ids)} end)

    # call update
    Enum.reduce(player_result_ids, [], fn {id, result_id}, acc ->
      (acc ++
         Stately.update(id, @atom, keys, %{id: result_id, player_id: id}, event))
      |> Stately.out_to_event(@atom, [:altered, repp])
      |> List.wrap()
    end)
  end

  def feed(
        %Event{
          id: _event_id,
          keys: [:match, :created, _orepp] = keys,
          data: %{id: match_id, player_ids: player_ids}
        } = event,
        repp
      ) do
    # for each participant
    # call update
    Enum.reduce(player_ids, [], fn id, acc ->
      acc ++
        [
          Stately.update(id, @atom, keys, %{id: match_id, player_id: id}, event)
          |> Stately.out_to_event(@atom, [:altered, repp])
        ]
    end)
  end

  def feed(%Event{id: _event_id, keys: [:read, @atom], data: %{player_id: id}}, repp) do
    player = read(id)
    [Event.new([@atom, :read, repp], %{out: player})]
  end

  def feed(%Event{id: _event_id, keys: [:read, :log, @atom], data: %{player_id: id}}, repp) do
    events = Data.read_log_by_id(id, @atom)
    [Event.new([@atom, :read, repp], %{out: events})]
  end

  def feed(_event, _orepp) do
    []
  end

  ## module
  def read(id) do
    Stately.read(id, @atom)
  end

  def exist?(id) do
    Stately.exist?(id, @atom)
  end

  def module_name() do
    @atom
  end

  ## gen
  @impl true
  def init({id, %PlayerInput{} = data, %Event{} = event}) do
    state = %Player{id: id, name: data.name, time: event.time}
    case Data.save_state_with_log(@atom, id, state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, state}
    end
    {:ok, state}
  end

  @impl true
  def init(%Player{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, @atom]}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(
        %Event{keys: [:deck, :created, _repp]} = event,
        _from,
        state
      ) do

    deck = Metr.read(event.data.out, :deck)

    new_state = Map.update!(state, :decks, &(&1 ++ [deck.id]))

    case Data.save_state_with_log(@atom, deck.player, state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:reply, "Deck #{deck.id} added to player #{deck.player}", new_state}
    end
  end

  @impl true
  def handle_call(
        %{keys: [:game, :created, _orepp], data: %{id: result_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :results, &(&1 ++ [result_id]))

    case Data.save_state_with_log(@atom, id, state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, new_state}
    end

    {:reply, "Result #{result_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:match, :created, _orepp], data: %{id: match_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :matches, &(&1 ++ [match_id]))

    case Data.save_state_with_log(@atom, id, state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, new_state}
    end

    {:reply, "Match #{match_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:game, :deleted, _orepp], data: %{id: result_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :results, fn results -> List.delete(results, result_id) end)

    case Data.save_state_with_log(@atom, id, state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, new_state}
    end

    {:reply, "Game #{result_id} removed from player #{id}", new_state}
  end

  @impl true
  def handle_call(%{keys: [:read, @atom]}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(
        %{keys: [:tagged], data: %{id: id, tag: tag}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))

    case Data.save_state_with_log(@atom, id, state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, state}
    end

    {:reply, "#{@atom} #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

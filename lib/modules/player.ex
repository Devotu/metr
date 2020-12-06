defmodule Metr.Modules.Player do
  defstruct id: "", name: "", decks: [], results: [], matches: [], time: 0

  @name "Player"

  use GenServer

  alias Metr.Modules.Base
  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Util
  alias Metr.Time

  def feed(
        %Event{id: _event_id, tags: [:create, :player], data: %{name: name} = data} = event,
        repp
      ) do
    id = Id.hrid(name)

    # Start genserver
    GenServer.start(Metr.Modules.Player, {id, data, event},
      name: Data.genserver_id(__ENV__.module, id)
    )

    # Return
    [Event.new([:player, :created, repp], %{id: id})]
  end

  def feed(
        %Event{
          id: _event_id,
          tags: [:deck, :created, _orepp] = tags,
          data: %{id: deck_id, player_id: id}
        } = event,
        repp
      ) do
    [
      Base.update(id, @name, tags, %{id: deck_id, player_id: id}, event)
      |> Base.out_to_event(@name, [:altered, repp])
    ]
  end

  def feed(
        %Event{
          id: _event_id,
          tags: [:game, :created, _orepp] = tags,
          data: %{result_ids: result_ids}
        } = event,
        repp
      ) do
    player_result_ids =
      result_ids
      |> Enum.map(fn result_id -> Result.read(result_id) end)
      |> Enum.map(fn r -> {r.player_id, r.id} end)

    # for each participant
    # call update
    Enum.reduce(
      player_result_ids,
      [],
      fn {id, result_id}, acc ->
        acc ++
          [
            Base.update(id, @name, tags, %{id: result_id, player_id: id}, event)
            |> Base.out_to_event(@name, [:altered, repp])
          ]
      end
    )
  end

  def feed(
        %Event{
          id: _event_id,
          tags: [:game, :deleted, _orepp] = tags,
          data: %{results: result_ids}
        } = event,
        repp
      ) do
    # for each player find connections to this game
    player_result_ids =
      Data.list_ids(__ENV__.module)
      |> Enum.map(fn id -> read(id) end)
      |> Enum.filter(fn p -> Util.has_member?(p.results, result_ids) end)
      |> Enum.map(fn p -> {p.id, Util.find_first_common_member(p.results, result_ids)} end)

    # call update
    Enum.reduce(player_result_ids, [], fn {id, result_id}, acc ->
      acc ++
        [
          Base.update(id, @name, tags, %{id: result_id, player_id: id}, event)
          |> Base.out_to_event(@name, [:altered, repp])
        ]
    end)
  end

  def feed(
        %Event{
          id: _event_id,
          tags: [:match, :created, _orepp] = tags,
          data: %{id: match_id, player_ids: player_ids}
        } = event,
        repp
      ) do
    # for each participant
    # call update
    Enum.reduce(player_ids, [], fn id, acc ->
      # acc ++ Base.update(id, @name, tags, %{id: match_id, player_id: id}, event)
      acc ++
        [
          Base.update(id, @name, tags, %{id: match_id, player_id: id}, event)
          |> Base.out_to_event(@name, [:altered, repp])
        ]
    end)
  end

  def feed(%Event{id: _event_id, tags: [:read, :player], data: %{player_id: id}}, repp) do
    player = read(id)
    [Event.new([:player, :read, repp], %{out: player})]
  end

  def feed(%Event{id: _event_id, tags: [:read, :log, :player], data: %{player_id: id}}, repp) do
    events = Data.read_log_by_id("Player", id)
    [Event.new([:player, :log, :read, repp], %{out: events})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :player]}, repp) do
    players =
      Data.list_ids(__ENV__.module)
      |> Enum.map(fn id -> read(id) end)

    [Event.new([:players, repp], %{players: players})]
  end

  def feed(_event, _orepp) do
    []
  end

  def read(id) do
    Base.read(id, @name)
  end

  def exist?(id) do
    Base.exist?(id, @name)
  end

  ## gen
  @impl true
  def init({id, data, event}) do
    state = %Player{id: id, name: data.name, time: Time.timestamp()}
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:ok, state}
  end

  def init(%Player{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(
        %{tags: [:deck, :created, _orepp], data: %{id: deck_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :decks, &(&1 ++ [deck_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Deck #{deck_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{tags: [:game, :created, _orepp], data: %{id: result_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :results, &(&1 ++ [result_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Result #{result_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{tags: [:match, :created, _orepp], data: %{id: match_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :matches, &(&1 ++ [match_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Match #{match_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{tags: [:game, :deleted, _orepp], data: %{id: result_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :results, fn results -> List.delete(results, result_id) end)
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Game #{result_id} removed from player #{id}", new_state}
  end

  @impl true
  def handle_call(%{tags: [:read, :player]}, _from, state) do
    {:reply, state, state}
  end
end

defmodule Metr.Modules.Player do
  defstruct id: "", name: "", decks: [], results: [], matches: [], time: 0, tags: []

  use GenServer

  alias Metr.Modules.Stately
  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Input.PlayerInput
  alias Metr.Util
  alias Metr.Time

  @name __ENV__.module |> Stately.module_to_name()

  def feed(
        %Event{id: _event_id, keys: [:create, :player], data: %PlayerInput{name: name}} = event,
        repp
      ) do
    validation =
      :ok
      |> Stately.is_accepted_name(name)

    case validation do
      :ok ->
        id = Id.hrid(name)
        state = %Player{id: id, name: name, time: Time.timestamp()}

        Stately.create("Player", state, event)
        |> Stately.out_to_event(@name, [:created, repp])
        |> List.wrap()

      {:error, e} ->
        [Event.new([:player, :error, repp], %{msg: e})]
    end
  end

  def feed(
        %Event{
          id: _event_id,
          keys: [:deck, :created, _orepp] = keys,
          data: %{id: deck_id, player_id: id}
        } = event,
        repp
      ) do
    [
      Stately.update(id, @name, keys, %{id: deck_id, player_id: id}, event)
      |> Stately.out_to_event(@name, [:altered, repp])
    ]
  end

  def feed(
        %Event{
          id: _event_id,
          keys: [:game, :created, _orepp] = keys,
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
            Stately.update(id, @name, keys, %{id: result_id, player_id: id}, event)
            |> Stately.out_to_event(@name, [:altered, repp])
          ]
      end
    )
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
      Data.list_ids(__ENV__.module)
      |> Enum.map(fn id -> read(id) end)
      |> Enum.filter(fn p -> Util.has_member?(p.results, result_ids) end)
      |> Enum.map(fn p -> {p.id, Util.find_first_common_member(p.results, result_ids)} end)

    # call update
    Enum.reduce(player_result_ids, [], fn {id, result_id}, acc ->
      (acc ++
         Stately.update(id, @name, keys, %{id: result_id, player_id: id}, event))
      |> Stately.out_to_event(@name, [:altered, repp])
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
          Stately.update(id, @name, keys, %{id: match_id, player_id: id}, event)
          |> Stately.out_to_event(@name, [:altered, repp])
        ]
    end)
  end

  def feed(%Event{id: _event_id, keys: [:read, :player], data: %{player_id: id}}, repp) do
    player = read(id)
    [Event.new([:player, :read, repp], %{out: player})]
  end

  def feed(%Event{id: _event_id, keys: [:read, :log, :player], data: %{player_id: id}}, repp) do
    events = Data.read_log_by_id(id, "Player")
    [Event.new([:player, :log, :read, repp], %{out: events})]
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

  ## gen
  @impl true
  def init(%Player{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(
        %{keys: [:deck, :created, _orepp], data: %{id: deck_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :decks, &(&1 ++ [deck_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Deck #{deck_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:game, :created, _orepp], data: %{id: result_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :results, &(&1 ++ [result_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Result #{result_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:match, :created, _orepp], data: %{id: match_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :matches, &(&1 ++ [match_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Match #{match_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:game, :deleted, _orepp], data: %{id: result_id, player_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :results, fn results -> List.delete(results, result_id) end)
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Game #{result_id} removed from player #{id}", new_state}
  end

  @impl true
  def handle_call(%{keys: [:read, :player]}, _from, state) do
    {:reply, state, state}
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

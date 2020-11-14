defmodule Metr.Player do
  defstruct id: "", name: "", decks: [], results: [], matches: []

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Player
  alias Metr.Result
  alias Metr.Util

  def feed(%Event{id: _event_id, tags: [:create, :player], data: %{name: name} = data} = event, repp) do
    id = Id.hrid(name)

    #Start genserver
    GenServer.start(Metr.Player, {id, data, event}, [name: Data.genserver_id(__ENV__.module, id)])

    #Return
    [Event.new([:player, :created, repp], %{id: id})]
  end

  def feed(%Event{id: _event_id, tags: [:deck, :created, _orepp] = tags, data: %{id: _deck_id, player_id: id} = data} = event, _repp) do
    update(id, tags, data, event)
  end

  def feed(%Event{id: _event_id, tags: [:game, :created, _orepp] = tags, data: %{id: game_id, player_ids: player_ids}} = event, _repp) do
    #for each participant
    #call update
    Enum.reduce(player_ids, [], fn id, acc -> acc ++ update(id, tags, %{id: game_id, player_id: id}, event) end)
  end

  def feed(%Event{id: _event_id, tags: [:game, :created, _orepp] = tags, data: %{result_ids: result_ids}} = event, _repp) do
    player_result_ids = result_ids
      |> Enum.map(fn result_id -> Result.read(result_id) end)
      |> Enum.map(fn r -> {r.player_id, r.id} end)
    #for each participant
    #call update
    Enum.reduce(
      player_result_ids,
      [],
      fn {player_id, result_id}, acc -> acc ++ update(player_id, tags, %{id: result_id, player_id: player_id}, event) end)
  end


  def feed(%Event{id: _event_id, tags: [:game, :deleted, _orepp] = tags, data: %{results: result_ids}} = event, _repp) do
    #for each player find connections to this game
    player_result_ids = Data.list_ids(__ENV__.module)
    |> Enum.map(fn id -> read(id) end)
    |> Enum.filter(fn p -> Util.has_member?(p.results, result_ids) end)
    |> Enum.map(fn p -> {p.id, Util.find_first_common_member(p.results, result_ids)} end)
    #call update
    Enum.reduce(player_result_ids, [], fn {id, result_id}, acc -> acc ++ update(id, tags, %{id: result_id, player_id: id}, event) end)
  end

  def feed(%Event{id: _event_id, tags: [:match, :created, _orepp] = tags, data: %{id: match_id, player_ids: player_ids}} = event, _repp) do
    #for each participant
    #call update
    Enum.reduce(player_ids, [], fn id, acc -> acc ++ update(id, tags, %{id: match_id, player_id: id}, event) end)
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
    players = Data.list_ids(__ENV__.module)
    |> Enum.map(fn id -> read(id) end)
    [Event.new([:players, repp], %{players: players})]
  end

  def feed(_event, _orepp) do
    []
  end


  def read(id) do
    id
    |> verify_id()
    |> ready_process()
    |> recall()
  end


  def exist?(id) do
    case verify_id(id) do
      {:ok, _id} -> true
      _ -> false
    end
  end


  ##private
  defp verify_id(id) do
    case Data.state_exists?(__ENV__.module, id) do
      true -> {:ok, id}
      false -> {:error, "player not found"}
    end
  end


  defp recall({:error, reason}), do: {:error, reason}
  defp recall({:ok, id}) do
    GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: [:read, :player]})
  end


  defp ready_process({:error, reason}), do: {:error, reason}
  defp ready_process({:ok, id}) do
    # Is running?
    case {GenServer.whereis(Data.genserver_id(__ENV__.module, id)), Data.state_exists?(__ENV__.module, id)} do
      {nil, true} ->
        start_process(id)
      {nil, false} ->
        {:error, :no_such_id}
      _ ->
        {:ok, id}
    end
  end


  defp start_process(id) do
    #Get state
    current_state = Map.merge(%Player{}, Data.recall_state(__ENV__.module, id))
    case GenServer.start(Metr.Player, current_state, [name: Data.genserver_id(__ENV__.module, id)]) do
      :ok -> {:ok, id}
      x -> x
    end
  end


  defp update(id, tags, data, event, repp \\ nil) do
    response = id
      |> verify_id()
      |> ready_process()
      |> alter(tags, data, event)

    case response do
      {:error, reson} ->
        [Event.new([:player, :error, repp], %{cause: reson})]
      msg ->
        [Event.new([:player, :altered, repp], %{out: msg})]
    end
  end


  defp alter({:error, reason}, _tags, _data, _event), do: {:error, reason}
  defp alter({:ok, id}, tags, data, event) do
    #Call update
    GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags, data: data, event: event})
  end


  ## gen
  @impl true
  def init({id, data, event}) do
    state = %Player{id: id, name: data.name}
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:ok, state}
  end

  def init(%Player{} = state) do
    {:ok, state}
  end


  @impl true
  def handle_call(%{tags: [:deck, :created, _orepp], data: %{id: deck_id, player_id: id}, event: event}, _from, state) do
    new_state = Map.update!(state, :decks, &(&1 ++ [deck_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Deck #{deck_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(%{tags: [:game, :created, _orepp], data: %{id: result_id, player_id: id}, event: event}, _from, state) do
    new_state = Map.update!(state, :results, &(&1 ++ [result_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Result #{result_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(%{tags: [:match, :created, _orepp], data: %{id: match_id, player_id: id}, event: event}, _from, state) do
    new_state = Map.update!(state, :matches, &(&1 ++ [match_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Match #{match_id} added to player #{id}", new_state}
  end


  @impl true
  def handle_call(%{tags: [:game, :deleted, _orepp], data: %{id: result_id, player_id: id}, event: event}, _from, state) do
    new_state = Map.update!(state, :results, fn results -> List.delete(results, result_id) end)
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Game #{result_id} removed from player #{id}", new_state}
  end

  @impl true
  def handle_call(%{tags: [:read, :player]}, _from, state) do
    {:reply, state, state}
  end
end

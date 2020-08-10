defmodule Metr.Player do
  defstruct id: "", name: "", decks: [], games: []

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Player

  def feed(%Event{id: _event_id, tags: [:create, :player], data: %{name: name}}, repp) do
    id = Id.hrid(name)
    #Log event #TODO replay by module?
    #Create state
    #The initialization is the only state change outside of a process
    player_state = %Player{id: id, name: name}
    #Save state
    Data.save_state(__ENV__.module, id, player_state)
    #Start genserver
    GenServer.start(Metr.Player, player_state, [name: Data.genserver_id(__ENV__.module, id)])

    #Return
    [Event.new([:player, :created, repp], %{id: id})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :player]}, repp) do
    players = Data.list_ids(__ENV__.module)
    |> Enum.map(fn id -> recall(id) end)
    [Event.new([:players, repp], %{players: players})]
  end

  def feed(%Event{id: _event_id, tags: [:deck, :created, _orepp] = tags, data: %{id: _deck_id, player_id: id} = data}, _repp) do
    update(id, tags, data)
  end

  def feed(%Event{id: _event_id, tags: [:game, :created, _orepp] = tags, data: %{id: game_id, player_ids: player_ids}}, _repp) do
    #for each participant
    #call update
    Enum.reduce(player_ids, [], fn id, acc -> acc ++ update(id, tags, %{id: game_id, player_id: id}) end)
  end

  def feed(%Event{id: _event_id, tags: [:read, :player] = tags, data: %{player_id: id}}, repp) do
    player = recall(id)
    [Event.new([:player, :read, repp], %{out: player})]
  end


  def feed(_event, _orepp) do
    []
  end


  defp update(id, tags, data) do
    ready_process(id)
    #Call update
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags, data: data})
    #Return
    [Event.new([:player, :altered], %{out: msg})]
  end


  defp recall(id) do
    ready_process(id)
    GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: [:read, :player]})
  end


  defp ready_process(id) do
    # Is running?
    if GenServer.whereis(Data.genserver_id(__ENV__.module, id)) == nil do
      #Get state
      current_state = Data.recall_state(__ENV__.module, id)
      #Start process
      GenServer.start(Metr.Player, current_state, [name: Data.genserver_id(__ENV__.module, id)])
    end
  end


  ## gen
  @impl true
  def init(state) do
    {:ok, state}
  end


  @impl true
  def handle_call(%{tags: [:deck, :created, _orepp], data: %{id: deck_id, player_id: id}}, _from, state) do
    new_state = Map.update!(state, :decks, &(&1 ++ [deck_id]))
    #Save state
    Data.save_state(__ENV__.module, id, new_state)
    #Reply
    {:reply, "Deck #{deck_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(%{tags: [:game, :created, _orepp], data: %{id: game_id, player_id: id}}, _from, state) do
    new_state = Map.update!(state, :games, &(&1 ++ [game_id]))
    #Save state
    Data.save_state(__ENV__.module, id, new_state)
    #Reply
    {:reply, "Game #{game_id} added to player #{id}", new_state}
  end

  @impl true
  def handle_call(%{tags: [:read, :player]}, _from, state) do
    #Reply
    {:reply, state, state}
  end
end

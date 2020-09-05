defmodule Metr.Deck do
  defstruct id: "", name: "", format: "", theme: "", black: false, white: false, red: false, green: false, blue: false, colorless: false, games: [], rank: nil

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Deck

  ##feed
  def feed(%Event{id: _event_id, tags: [:create, :deck], data: %{name: name, player_id: player_id} = data}, repp) do
    case Data.state_exists?("Player", player_id) do
      false ->
        #Return
        [Event.new([:deck, :create, :fail], %{cause: "player not found", data: data})]
      true ->
        #Create state
        #The initialization is the only state change outside of a process
        deck_state = build_state(Id.hrid(name), data)
        #Save state
        :ok = Data.save_state(__ENV__.module, deck_state.id, deck_state)
        #Start genserver
        GenServer.start(Metr.Deck, deck_state, [name: Data.genserver_id(__ENV__.module, deck_state.id)])

        #Return
        [Event.new([:deck, :created, repp], %{id: deck_state.id, player_id: player_id})]
    end
  end

  def feed(%Event{id: _event_id, tags: [:game, :created, _orepp] = tags, data: %{id: game_id, deck_ids: deck_ids}}, _repp) do
    #for each participant
    #call update
    Enum.reduce(deck_ids, [], fn id, acc -> acc ++ update(id, tags, %{id: game_id, deck_id: id}) end)
  end

  def feed(%Event{id: _event_id, tags: [:game, :deleted, _orepp] = tags, data: %{id: game_id}}, _repp) do
    #for each deck find connections to this game
    deck_ids = Data.list_ids(__ENV__.module)
    |> Enum.map(fn id -> recall(id) end)
    |> Enum.filter(fn d -> Enum.member?(d.games, game_id) end)
    |> Enum.map(fn d -> d.id end)
    #call update
    Enum.reduce(deck_ids, [], fn id, acc -> acc ++ update(id, tags, %{id: game_id, deck_id: id}) end)
  end

  def feed(%Event{id: _event_id, tags: [:read, :deck], data: %{deck_id: id}}, repp) do
    deck = recall(id)
    [Event.new([:deck, :read, repp], %{out: deck})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :deck]}, repp) do
    decks = Data.list_ids(__ENV__.module)
    |> Enum.map(fn id -> recall(id) end)
    [Event.new([:decks, repp], %{decks: decks})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :game], data: %{deck_id: id}}, repp) do
    deck = recall(id)
    [{Event.new([:list, :game], %{ids: deck.games}), repp}]
  end

  def feed(_event, _orepp) do
    []
  end



  ##private
  defp ready_process(id) do
    # Is running?
    if GenServer.whereis(Data.genserver_id(__ENV__.module, id)) == nil do
      #Get state
      current_state = Data.recall_state(__ENV__.module, id)
      #Start process
      GenServer.start(Metr.Deck, current_state, [name: Data.genserver_id(__ENV__.module, id)])
    end
  end

  defp update(id, tags, data) do
    ready_process(id)
    #Call update
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags, data: data})
    #Return
    [Event.new([:deck, :altered], %{out: msg})]
  end

  defp recall(id) do
    ready_process(id)
    GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: [:read, :deck]})
  end



  defp build_state(id, %{name: name, player_id: _player_id} = data) do
    %Deck{id: id, name: name}
    |> apply_colors(data)
    |> apply_rank(data)
  end


  defp apply_colors(%Deck{} = deck, data) when is_map(data) do
    case Map.has_key?(data, :colors) do
      true ->
        Enum.reduce(data.colors, deck, fn c,d -> apply_color(c, d) end)
      false ->
        deck
    end
  end

  defp apply_color(color, %Deck{} = deck) when is_atom(color) do
    Map.put(deck, color, true)
  end


  defp apply_rank(%Deck{} = deck, data) when is_map(data) do
    case Map.has_key?(data, :rank) and is_tuple(data.rank) do
      true ->
        Map.update!(deck, :rank, fn _r -> data.rank end)
      false ->
        deck
    end
  end



  ## gen
  @impl true
  def init(state) do
    {:ok, state}
  end


  @impl true
  def handle_call(%{tags: [:read, :deck]}, _from, state) do
    #Reply
    {:reply, state, state}
  end


  @impl true
  def handle_call(%{tags: [:game, :created, _orepp], data: %{id: game_id, deck_id: id}}, _from, state) do
    new_state = Map.update!(state, :games, &(&1 ++ [game_id]))
    #Save state
    Data.save_state(__ENV__.module, id, new_state)
    #Reply
    {:reply, "Game #{game_id} added to deck #{id}", new_state}
  end


  @impl true
  def handle_call(%{tags: [:game, :deleted, _orepp], data: %{id: game_id, deck_id: id}}, _from, state) do
    new_state = Map.update!(state, :games, fn games -> List.delete(games, game_id) end)
    #Save state
    Data.save_state(__ENV__.module, id, new_state)
    #Reply
    {:reply, "Game #{game_id} removed from deck #{id}", new_state}
  end
end

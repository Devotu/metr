defmodule Metr.Deck do
  defstruct id: "", name: "", format: "", theme: "", black: false, white: false, red: false, green: false, blue: false, colorless: false, games: [], rank: nil

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Deck
  alias Metr.Rank

  ##feed
  def feed(%Event{id: _event_id, tags: [:create, :deck], data: %{name: name, player_id: player_id} = data} = event, repp) do
    case Data.state_exists?("Player", player_id) do
      false ->
        #Return
        [Event.new([:deck, :create, :fail], %{cause: "player not found", data: data})]
      true ->
        id = Id.hrid(name)
        process_name = Data.genserver_id(__ENV__.module, id)
        #Start genserver
        case GenServer.start(Metr.Deck, {id, data, event}, [name: process_name]) do
          {:ok, _pid} -> [Event.new([:deck, :created, repp], %{id: id, player_id: player_id})]
          {:error, error} -> [Event.new([:deck, :not, :created, repp], %{errors: [error]})]
        end
    end
  end

  def feed(%Event{id: _event_id, tags: [:game, :created, _orepp] = tags, data: %{id: game_id, deck_ids: deck_ids}} = event, _repp) do
    #for each participant
    #call update
    Enum.reduce(deck_ids, [], fn id, acc -> acc ++ update(id, tags, %{id: game_id, deck_id: id}, event) end)
  end

  def feed(%Event{id: _event_id, tags: [:game, :deleted, _orepp] = tags, data: %{id: game_id}} = event, _repp) do
    #for each deck find connections to this game
    deck_ids = Data.list_ids(__ENV__.module)
    |> Enum.map(fn id -> recall(id) end)
    |> Enum.filter(fn d -> Enum.member?(d.games, game_id) end)
    |> Enum.map(fn d -> d.id end)
    #call update
    Enum.reduce(deck_ids, [], fn id, acc -> acc ++ update(id, tags, %{id: id, game_id: game_id}, event) end)
  end

  def feed(%Event{id: _event_id, tags: [:read, :log, :deck], data: %{deck_id: id}}, repp) do
    events = Data.read_log_by_id("Deck", id)
    [Event.new([:deck, :log, :read, repp], %{out: events})]
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

  def feed(%Event{id: _event_id, tags: [:rank, :altered] = tags, data: %{deck_id: id, change: change}} = event, _repp) do
    #call update
    update(id, tags, %{id: id, change: change}, event)
  end

  def feed(%Event{id: _event_id, tags: [:list, :format]}, repp) do
    [Event.new([:formats, repp], %{formats: list_formats()})]
  end

  def feed(_event, _orepp) do
    []
  end



  ##private
  defp ready_process(id) do
    # Is running?
    if GenServer.whereis(Data.genserver_id(__ENV__.module, id)) == nil do
      #Get state
      current_state = Map.merge(%Deck{}, Data.recall_state(__ENV__.module, id))
      #Start process
      {:ok, _pid} = GenServer.start(Metr.Deck, current_state, [name: Data.genserver_id(__ENV__.module, id)])
    end
  end

  defp update(id, tags, data, event) do
    ready_process(id)
    #Call update
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags, data: data, event: event})
    #Return
    [Event.new([:deck, :altered], %{out: msg})]
  end

  defp recall(id) do
    ready_process(id)
    GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: [:read, :deck]})
  end



  defp build_state(id, %{name: name} = data) do
    %Deck{id: id, name: name}
    |> apply_colors(data)
    |> apply_format(data)
    |> apply_rank(data)
  end


  defp apply_colors({:error, _error} = e, _data), do: {e}
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

  defp apply_format({:error, _error} = e, _data), do: e
  defp apply_format(%Deck{} = deck, data) when is_map(data) do
    case Map.has_key?(data, :format) do
      true ->
        apply_format(deck, data.format)
      false ->
        deck
    end
  end

  defp apply_format(deck, format_descriptor) when is_bitstring(format_descriptor) do
    case String.downcase(format_descriptor) do
      f when f in ["standard", "pauper"] -> Map.put(deck, :format, format_descriptor)
      _ -> {:error, :invalid_format}
    end
  end


  defp apply_rank({:error, _error} = e, _data), do: e
  defp apply_rank(%Deck{} = deck, data) when is_map(data) do
    case Map.has_key?(data, :rank) and is_tuple(data.rank) do
      true ->
        Map.update!(deck, :rank, fn _r -> data.rank end)
      false ->
        deck
    end
  end


  defp find_original_rank(%Event{data: %{rank: rank}}), do: rank
  defp find_original_rank(_), do: nil


  defp recalculate_rank(state, base_rank) do
    rank = state.games
    |> Enum.map(fn game_id -> Metr.read_game(game_id) end)
    |> Enum.filter(fn g -> g.ranking end)
    |> Enum.reduce([], fn(g, acc) -> acc ++ g.participants end)
    |> Enum.filter(fn p -> state.id == p.deck_id end)
    |> Enum.reduce(base_rank, fn(p, acc) -> Rank.apply_change(acc, Rank.find_change(p)) end)

    Map.put(state, :rank, rank)
  end


  defp list_formats() do
    ["block", "standard", "pauper"]
  end



  ## gen
  @impl true
  def init({id, data, event}) do
    case build_state(id, data) do
      {:error, error} ->
        {:stop, error}
      state ->
        :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
        {:ok, state}
    end
  end

  def init(%Deck{} = state) do
    {:ok, state}
  end


  @impl true
  def handle_call(%{tags: [:read, :deck]}, _from, state) do
    #Reply
    {:reply, state, state}
  end


  @impl true
  def handle_call(%{tags: [:game, :created, _orepp], data: %{id: game_id, deck_id: id}, event: event}, _from, state) do
    new_state = Map.update!(state, :games, &(&1 ++ [game_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "Game #{game_id} added to deck #{id}", new_state}
  end


  @impl true
  def handle_call(%{tags: [:game, :deleted, _orepp], data: %{id: id, game_id: game_id}, event: event}, _from, state) do
    original_rank = Data.read_log_by_id("Deck", id)
      |> Enum.filter(fn e -> e.tags == [:create, :deck] end)
      |> List.first()
      |> find_original_rank()

    new_state = state
      |> Map.update!(:games, fn games -> List.delete(games, game_id) end)
      |> recalculate_rank(original_rank)
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Game #{game_id} removed from deck #{id}", new_state}
  end


  @impl true
  def handle_call(%{tags: [:rank, :altered], data: %{id: id, change: change}, event: event}, _from, state) do
    new_state = Map.update!(state, :rank, fn rank -> Rank.apply_change(rank, change) end)
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "Deck #{id} rank altered to #{Kernel.inspect(new_state.rank)}", new_state}
  end
end

defmodule Metr.Game do
  defstruct id: "", time: 0, participants: [], ranking: false

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Deck
  alias Metr.Game
  alias Metr.Rank
  alias Metr.Time


  ## feed
  def feed(%Event{id: _event_id, tags: [:create, :game], data: data} = event, repp) do
    id = Id.guid()

    rank_events = collect_rank_alterations(data)

    #If any contains errors don't alter state
    error_events = Event.only_errors(rank_events)

    #Return
    case Enum.count(error_events) > 0 do
      true ->
        error_events
        |> Enum.map(fn e -> Event.add_repp(e, repp) end)
      false ->
        rank_events ++ initiate_state({id, data, event}, repp)
    end
  end

  def feed(%Event{id: _event_id, tags: [:read, :game] = tags, data: %{game_id: id}}, repp) do
    ready_process(id)
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags})
    [Event.new([:deck, :read, repp], %{out: msg})]
  end

  def feed(%Event{id: _event_id, tags: [:read, :log, :game], data: %{game_id: id}}, repp) do
    events = Data.read_log_by_id("Game", id)
    [Event.new([:game, :log, :read, repp], %{out: events})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :game], data: %{ids: ids}}, repp) when is_list(ids) do
    games = Enum.map(ids, &recall/1)
    [Event.new([:games, repp], %{games: games})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :game], data: %{limit: limit}}, repp) when is_number(limit) do
    games = Data.list_ids(__ENV__.module)
      |> Enum.map(&recall/1)
      |> Enum.sort(&(&1.time < &2.time))
      |> Enum.take(limit)
    [Event.new([:games, repp], %{games: games})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :game]}, repp) do
    games = Data.list_ids(__ENV__.module)
    |> Enum.map(&recall/1)
    [Event.new([:games, repp], %{games: games})]
  end

  def feed(%Event{id: _event_id, tags: [:delete, :game], data: %{game_id: game_id}}, repp) do
    case Data.wipe_state(__ENV__.module, game_id) do
      :ok -> [Event.new([:game, :deleted, repp], %{id: game_id})]
      _ -> [Event.new([:game, :not, :deleted, repp], %{id: game_id})]
    end
  end

  def feed(_event, _orepp) do
    []
  end


  defp ready_process(id) do
    # Is running?
    if GenServer.whereis(Data.genserver_id(__ENV__.module, id)) == nil do
      #Get state
      current_state = Map.merge(%Game{}, Data.recall_state(__ENV__.module, id))
      #Start process
      GenServer.start(Metr.Game, current_state, [name: Data.genserver_id(__ENV__.module, id)])
    end
  end

  defp recall(id) do
    ready_process(id)
    GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: [:read, :game]})
  end


  defp convert_to_participants(parts, winner) do
    parts
    |> Enum.map(fn p -> fill_power(p) end)
    |> Enum.map(fn p -> fill_fun(p) end)
    |> Enum.map(fn p -> part_to_participant(p, winner) end)
  end


  defp initiate_state({id, data, event}, repp) do
    process_name = Data.genserver_id(__ENV__.module, id)

    case GenServer.start(Metr.Game, {id, data, event}, [name: process_name]) do
      {:ok, _pid} ->
        participants = convert_to_participants(data.parts, data.winner)
        player_ids =  Enum.map(participants, fn p -> p.player_id end)
        deck_ids = Enum.map(participants, fn p -> p.deck_id end)
        [Event.new([:game, :created, repp], %{id: id, player_ids: player_ids, deck_ids: deck_ids, ranking: data.rank})]
      _ ->
        Event.new([:game, :error, repp], %{msg: "Could not save game state"})
    end
  end


  defp fill_power(%{part: part, details: %{player_id: _player, deck_id: _deck, power: _power} = details}) do
    %{part: part, details: details}
  end

  defp fill_power(%{part: part, details: %{player_id: _player, deck_id: _deck} = details}) do
    %{part: part, details: Map.put(details, :power, nil)}
  end


  defp fill_fun(%{part: part, details: %{player_id: _player, deck_id: _deck, fun: _power} = details}) do
    %{part: part, details: details}
  end

  defp fill_fun(%{part: part, details: %{player_id: _player, deck_id: _deck} = details}) do
    %{part: part, details: Map.put(details, :fun, nil)}
  end


  defp fill_rank(%{rank: nil} = deck), do: Map.update!(deck, :rank, fn _r -> {0,0} end)
  defp fill_rank(deck), do: deck


  defp part_to_participant(part, winner) do
    %{
      player_id: part.details.player_id,
      deck_id: part.details.deck_id,
      place: place(part.part, winner),
      power: part.details.power,
      fun: part.details.fun
    }
  end


  defp place(_part_id, 0), do: 0
  defp place(part_id, winner_id) do
    case part_id == winner_id do
      true -> 1
      false -> 2
    end
  end


  defp collect_rank_alterations(%{rank: false}), do: []
  defp collect_rank_alterations(%{rank: true} = data) do
    participants = convert_to_participants(data.parts, data.winner)
    case ranks_match?(participants) do
      true ->
        Enum.map(participants, fn p -> rank_participant(p) end)
      false ->
        [Event.new([:game, :error], %{msg: "Ranks does not match"})]
    end
  end


  defp ranks_match?(participants) do
    1 == participants
      |> Enum.map(fn p -> get_deck(p.deck_id) end)
      |> Enum.map(fn e -> e.data.out end)
      |> Enum.map(fn d -> fill_rank(d) end)
      |> Enum.map(fn d -> d.rank end)
      |> Enum.map(fn {rank, _delta} -> rank end)
      |> Enum.dedup_by(fn r -> r end)
      |> Enum.count()
  end


  defp get_deck(deck_id) do
    Event.new([:read, :deck], %{deck_id: deck_id})
      |> Deck.feed(nil)
      |> List.first()
  end


  defp rank_participant(%{deck_id: deck_id} = p) do
    Event.new([:rank, :altered], %{deck_id: deck_id, change: Rank.find_change(p)})
  end



  ## gen
  @impl true
  def init({id, data, event}) do
    participants = convert_to_participants(data.parts, data.winner)
    state = %Game{
      id: id,
      time: Time.timestamp(),
      participants: participants,
      ranking: data.rank
    }
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:ok, state}
  end

  def init(%Game{} = state) do
    {:ok, state}
  end


  @impl true
  def handle_call(%{tags: [:read, :game]}, _from, state) do
    #Reply
    {:reply, state, state}
  end
end

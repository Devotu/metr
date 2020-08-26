defmodule Metr.Game do
  defstruct id: "", time: 0, participants: []

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Game


  ## feed
  def feed(%Event{id: _event_id, tags: [:create, :game], data: data}, repp) do
    game_id = Id.guid()

    #Create state
    #The initialization is the only state change outside of a process
    game_state = %Game{
      id: game_id,
      time: DateTime.utc_now() |> DateTime.to_unix(),
      participants: convert_to_participants(data.parts, data.winner)
    }

    #Save state
    Data.save_state(__ENV__.module, game_id, game_state)

    #Start genserver
    GenServer.start(Metr.Game, game_state, [name: Data.genserver_id(__ENV__.module, game_id)])

    player_ids = game_state.participants
      |> Enum.map(fn p -> p.player_id end)

    deck_ids = game_state.participants
      |> Enum.map(fn p -> p.deck_id end)

    #Return
    [Event.new([:game, :created, repp], %{id: game_id, player_ids: player_ids, deck_ids: deck_ids})]
  end

  def feed(%Event{id: _event_id, tags: [:read, :game] = tags, data: %{game_id: id}}, repp) do
    ready_process(id)
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags})
    [Event.new([:deck, :read, repp], %{out: msg})]
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
      current_state = Data.recall_state(__ENV__.module, id)
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



  ## gen
  @impl true
  def init(state) do
    {:ok, state}
  end


  @impl true
  def handle_call(%{tags: [:read, :game]}, _from, state) do
    #Reply
    {:reply, state, state}
  end
end

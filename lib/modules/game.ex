defmodule Metr.Game do
  defstruct id: "", time: 0, results: [], match: nil

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Game
  alias Metr.Time
  alias Metr.Result


  ## feed
  def feed(%Event{id: _event_id, tags: [:create, :game], data: data} = event, repp) do
    case verify_input_data(data) do
      {:error, error} ->
        [Event.new([:game, :error, repp], %{cause: error, data: data})]
      {:ok} ->
        id = Id.guid()
        process_name = Data.genserver_id(__ENV__.module, id)
        results = convert_to_results(data.parts, data.winner)
        result_ids = results
          |> Enum.map(fn r -> Map.put(r, :game_id, id) end)
          |> Enum.map(fn r -> Result.create(r, event) end)
          |> Enum.map(fn {:ok, r} -> r.id end)
        case GenServer.start(Metr.Game, {id, result_ids, event}, [name: process_name]) do
          {:ok, _pid} ->
            match_id = Map.get(data, :match, nil)
            [Event.new([:game, :created, repp], %{id: id, result_ids: result_ids, ranking: data.rank, match_id: match_id})]
          {:error, error} ->
            [Event.new([:game, :not, :created, repp], %{errors: [error]})]
          _ ->
            [Event.new([:game, :error, repp], %{msg: "Could not save game state"})]
        end
    end
  end

  def feed(%Event{id: _event_id, tags: [:read, :game] = tags, data: %{game_id: id}}, repp) do
    case ready_process(id) do
      {:ok, id} ->
        msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags})
        [Event.new([:game, :read, repp], %{out: msg})]
      x ->
        [Event.new([:game, :error, repp], %{out: Kernel.inspect(x)})]
    end

  end

  def feed(%Event{id: _event_id, tags: [:read, :log, :game], data: %{game_id: id}}, repp) do
    events = Data.read_log_by_id("Game", id)
    [Event.new([:game, :log, :read, repp], %{out: events})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :game], data: %{ids: ids}}, repp) when is_list(ids) do
    games = Enum.map(ids, &read/1)
    [Event.new([:games, repp], %{games: games})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :game], data: %{limit: limit}}, repp) when is_number(limit) do
    games = Data.list_ids(__ENV__.module)
      |> Enum.map(&read/1)
      |> Enum.sort(&(&1.time < &2.time))
      |> Enum.take(limit)
    [Event.new([:games, repp], %{games: games})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :game]}, repp) do
    games = Data.list_ids(__ENV__.module)
    |> Enum.map(&read/1)
    [Event.new([:games, repp], %{games: games})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :result], data: %{game_id: id}}, repp) do
    game = read(id)
    [{Event.new([:list, :result], %{ids: game.results}), repp}]
  end

  def feed(%Event{id: _event_id, tags: [:delete, :game], data: %{game_id: game_id}}, repp) do
    delete_conclusion = game_id
      |> read()
      |> delete_game_results()
      |> delete_game()
    case delete_conclusion do
      %Game{} = game -> [Event.new([:game, :deleted, repp], %{id: game_id, results: game.results})]
      {:error, reason} -> [Event.new([:game, :error, repp], %{msg: reason})]
      _ -> [Event.new([:game, :error, repp], %{msg: "unknown error"})]
    end
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
    id
    |> verify_id()
  end


  ##private
  defp verify_id(id) do
    case Data.state_exists?(__ENV__.module, id) do
      true -> {:ok, id}
      false -> {:error, "game not found"}
    end
  end


  defp recall({:error, reason}), do: {:error, reason}
  defp recall({:ok, id}) do
    GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: [:read, :game]})
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
  defp ready_process(id), do: ready_process({:ok, id})


  defp start_process(id) do
    #Get state
    current_state = Map.merge(%Game{}, Data.recall_state(__ENV__.module, id))
    case GenServer.start(Metr.Game, current_state, [name: Data.genserver_id(__ENV__.module, id)]) do
      :ok -> {:ok, id}
      x -> x
    end
  end


  defp convert_to_results(parts, winner) do
    parts
    |> Enum.map(fn p -> fill_power(p) end)
    |> Enum.map(fn p -> fill_fun(p) end)
    |> Enum.map(fn p -> part_to_result(p, winner) end)
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


  defp verify_input_data(data) do
    {:ok}
    |> verify_players(data)
    |> verify_decks(data)
  end

  defp verify_players({:error, _cause} = error, _id), do: error
  defp verify_players({:ok}, %{parts: [%{details: %{player_id: _id1}}, %{details: %{player_id: _id2}}]}), do: {:ok}
  defp verify_players({:ok}, %{player_1_id: _p1, player_2_id: _p2}), do: {:ok}
  defp verify_players({:ok}, _data), do: {:error, "missing player_id parameter"}

  defp verify_decks({:error, _cause} = error, _id), do: error
  defp verify_decks({:ok}, %{parts: [%{details: %{deck_id: _id1}}, %{details: %{deck_id: _id2}}]}), do: {:ok}
  defp verify_decks({:ok}, _data), do: {:error, "missing deck_id parameter"}


  defp part_to_result(part, winner) do
    %Result{
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


  defp delete_game_results({:error, reason}), do: {:error, reason}
  defp delete_game_results(%Game{} = game) do
    all_deleted? = game.results
      |> Enum.map(fn rid -> Result.delete(rid) end)
      |> Enum.all?(fn x -> x == :ok end)
    case all_deleted? do
      true -> game
      false -> {:error, "Not all results deleted"}
    end
  end


  defp delete_game({:error, reason}), do: {:error, reason}
  defp delete_game(%Game{} = game) do
    case Data.wipe_state(__ENV__.module, game.id) do
      :ok -> game
      _   -> {:error, "Could not delete game state"}
    end
  end



  ## gen
  @impl true
  def init({id, result_ids, event}) do
    state = %Game{id: id, time: Time.timestamp(), results: result_ids}
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

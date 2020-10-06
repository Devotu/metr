defmodule Metr.Match do
  defstruct id: "", games: [], player_one: "", player_two: "", deck_one: "", deck_two: "", ranking: false, status: :new

  use GenServer

  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Match


  ## feed
  def feed(%Event{id: _event_id, tags: [:create, :match], data: data} = event, repp) do
    id = Id.guid()

    case Data.state_exists?("Player", data.player_1) do #TODO validate players and decks
      false ->
        #Return
        [Event.new([:match, :create, :fail], %{cause: "player not found", data: data})]
      true ->
        process_name = Data.genserver_id(__ENV__.module, id)
        #Start genserver
        case GenServer.start(Match, {id, data, event}, [name: process_name]) do
          {:ok, _pid} -> [Event.new([:match, :created, repp], %{id: id, player_1: data.player_1})] #TODO rest of players and decks
          {:error, error} -> [Event.new([:match, :not, :created, repp], %{errors: [error]})]
        end
    end
  end

  def feed(%Event{id: _event_id, tags: [:read, :match] = tags, data: %{match_id: id}}, repp) do
    ready_process(id)
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags})
    [Event.new([:match, :read, repp], %{out: msg})]
  end

  def feed(%Event{id: _event_id, tags: [:read, :log, :match], data: %{match_id: id}}, repp) do
    events = Data.read_log_by_id("Match", id)
    [Event.new([:match, :log, :read, repp], %{out: events})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :match], data: %{ids: ids}}, repp) when is_list(ids) do
    matches = Enum.map(ids, &recall/1)
    [Event.new([:matchs, repp], %{matches: matches})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :match]}, repp) do
    matches = Data.list_ids(__ENV__.module)
    |> Enum.map(&recall/1)
    [Event.new([:matchs, repp], %{matches: matches})]
  end

  def feed(%Event{id: _event_id, tags: [:game, :created, _orepp], data: %{id: _game_id, match_id: nil}}, _repp) do
    []
  end

  def feed(%Event{id: _event_id, tags: [:game, :created, _orepp], data: %{id: _game_id, match_id: id}} = event, _repp) do
    update(id, event.tags, event.data, event)
  end

  def feed(_event, _orepp) do
    []
  end


  defp ready_process(id) do
    # Is running?
    if GenServer.whereis(Data.genserver_id(__ENV__.module, id)) == nil do
      #Get state
      current_state = Map.merge(%Match{}, Data.recall_state(__ENV__.module, id))
      #Start process
      GenServer.start(Match, current_state, [name: Data.genserver_id(__ENV__.module, id)])
    end
  end

  defp recall(id) do
    ready_process(id)
    GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: [:read, :match]})
  end

  defp update(id, tags, data, event) do
    ready_process(id)
    #Call update
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags, data: data, event: event})
    #Return
    [Event.new([:match, :altered], %{out: msg})]
  end



  ## gen
  @impl true
  def init({id, data, event}) do
    state = %Match{
      id: id,
      player_one: data.player_1,
      player_two: data.player_2,
      deck_one: data.deck_1,
      deck_two: data.deck_2,
      status: :initialized
    }
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:ok, state}
  end


  @impl true
  def handle_call(%{tags: [:read, :match]}, _from, state) do
    #Reply
    {:reply, state, state}
  end

  @impl true
  def handle_call(%{tags: [:game, :created, _orepp], data: %{id: game_id, match_id: id}, event: event}, _from, state) do
    new_state = state
      |> Map.update!(:games, &(&1 ++ [game_id]))
      |> Map.put(:status, :open)
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    #Reply
    {:reply, "Game #{game_id} added to match #{id}", new_state}
  end
end

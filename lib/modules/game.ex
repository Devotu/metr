defmodule Metr.Game do
  defstruct id: "", time: 0, participants: []

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Game

  def feed(%Event{id: _event_id, tags: [:create, :game], data: data}) do
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
    [Event.new([:game, :created], %{id: game_id, player_ids: player_ids, deck_ids: deck_ids})]
  end

  def feed(%Event{id: _event_id, tags: [:read, :game] = tags, data: %{game_id: id}}) do
    ready_process(id)
    msg = GenServer.call(Data.genserver_id(__ENV__.module, id), %{tags: tags})
    [Event.new([:deck, :read], %{msg: msg})]
  end

  def feed(_) do
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


  defp convert_to_participants(parts, winner) do
    parts
    |> Enum.map(fn p -> fill_force(p) end)
    |> Enum.map(fn p -> fill_fun(p) end)
    |> Enum.map(fn p -> part_to_participant(p, winner) end)
  end


  defp fill_force(%{part: part, details: %{player_id: _player, deck_id: _deck, force: _force} = details}) do
    %{part: part, details: details}
  end

  defp fill_force(%{part: part, details: %{player_id: _player, deck_id: _deck} = details}) do
    %{part: part, details: Map.put(details, :force, nil)}
  end


  defp fill_fun(%{part: part, details: %{player_id: _player, deck_id: _deck, fun: _force} = details}) do
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
      force: part.details.force,
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

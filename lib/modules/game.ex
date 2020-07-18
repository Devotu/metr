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

    #Return
    [Event.new([:game, :created], %{id: game_id})]
  end


  def feed(_) do
    []
  end



  defp convert_to_participants(parts, winner) do
    parts
    |> Enum.map(fn p -> fill_force(p) end)
    |> Enum.map(fn p -> fill_fun(p) end)
    |> Enum.map(fn p -> part_to_participant(p, winner) end)
  end


  defp fill_force(%{part: part, details: %{player: _player, deck: _deck, force: _force} = details}) do
    %{part: part, details: details}
  end

  defp fill_force(%{part: part, details: %{player: _player, deck: _deck} = details}) do
    %{part: part, details: Map.put(details, :force, nil)}
  end


  defp fill_fun(%{part: part, details: %{player: _player, deck: _deck, fun: _force} = details}) do
    %{part: part, details: details}
  end

  defp fill_fun(%{part: part, details: %{player: _player, deck: _deck} = details}) do
    %{part: part, details: Map.put(details, :fun, nil)}
  end


  defp part_to_participant(part, winner) do
    %{
      player: part.details.player,
      deck: part.details.deck,
      place: place(part.part, winner),
      force: part.details.force,
      fun: part.details.fun
    }
  end


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
  def handle_call(%Event{id: _event_id, tags: [:deck, :created], data: %{id: deck_id, player_id: player_id}}, _from, state) do
    new_state = Map.update!(state, :decks, &(&1 ++ [deck_id]))
    #Save state
    Data.save_state(__ENV__.module, player_id, new_state)
    #Reply
    {:reply, "Deck #{deck_id} added to player #{player_id}", new_state}
  end
end

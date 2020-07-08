defmodule Metr.Player do
  defstruct id: "", name: "", decks: []

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Player

  def feed(%Event{id: _event_id, tags: [:create, :player], data: %{name: name}}) do
    player_id = Id.hrid(name)
    #Log event #TODO replay by module?
    #Create state
    #The initialization is the only state change outside of a process
    player_state = %Player{id: player_id, name: name}
    #Save state
    Data.save_state(__ENV__.module, player_id, player_state)
    #Start genserver
    GenServer.start(Metr.Player, player_state, [name: Data.genserver_id(__ENV__.module, player_id)])

    #Return
    [Event.new([:player, :created], %{id: player_id})]
  end

  def feed(%Event{id: _event_id, tags: [:deck, :created], data: %{id: _deck_id, player_id: player_id}} = event) do
    #Is running?
    case GenServer.whereis(Data.genserver_id(__ENV__.module, player_id)) do
      nil ->
        #Get state
        current_state = Data.recall_state(__ENV__.module, player_id)
        #Start process
        GenServer.start(Metr.Player, current_state, [name: Data.genserver_id(__ENV__.module, player_id)])
        #Call update
        msg = GenServer.call(Data.genserver_id(__ENV__.module, player_id), event)
        #Return
        [Event.new([:player, :altered], %{msg: msg})]
      _ ->
        #Call update
        msg = GenServer.call(Data.genserver_id(__ENV__.module, player_id), event)
        #Return
        [Event.new([:player, :altered], %{msg: msg})]
    end
  end

  def feed(_) do
    []
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

defmodule Metr.Deck do
  defstruct id: "", name: ""

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data

  def feed(%Event{id: _event_id, tags: [:create, :deck], data: %{name: name, player_id: player_id} = data}) do
    case Data.state_exists?("Player", player_id) do
      false ->
        #Return
        [Event.new([:deck, :create, :fail], %{cause: "player not found", data: data})]
      true ->
        deck_id = Id.hrid(name)
        #Create state
        #The initialization is the only state change outside of a process
        deck_state = %{id: deck_id, name: name}
        #Save state
        Data.save_state(__ENV__.module, deck_id, deck_state)
        #Start genserver
        GenServer.start(Metr.Deck, deck_state, [name: Data.genserver_id(__ENV__.module, deck_id)])

        #Return
        [Event.new([:deck, :created], %{id: deck_id, player_id: player_id})]
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
end

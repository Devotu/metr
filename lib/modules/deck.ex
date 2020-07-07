defmodule Metr.Deck do
  defstruct id: "", name: ""

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data

  def feed(%Event{id: _event_id, tags: [:create, :deck], data: %{name: name, player_id: player_id}}) do
    case Data.state_exists?("Player", player_id) do
      false ->
        IO.puts("false")
        {:error, :id_not_found}
      true ->
        IO.puts("true")
        deck_id = Id.hrid(name)
        #Create state
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

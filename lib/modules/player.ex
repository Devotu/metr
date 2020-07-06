defmodule Metr.Player do
  defstruct id: "", name: ""

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data

  def feed(%Event{id: _event_id, tags: [:create, :player], data: %{name: name}}) do
    player_id = Id.hrid(name)
    #Log event #TODO replay by module?
    #Create state
    player_state = %{id: player_id, name: name}
    #Save state
    Data.save_state(__ENV__.module, player_id, player_state)
    #Start genserver
    GenServer.start(Metr.Player, player_state, [name: Data.genserver_id(__ENV__.module, player_id)])

    #Return
    [Event.new([:player, :created], %{id: player_id})]
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

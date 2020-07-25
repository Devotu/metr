defmodule Metr.Deck do
  defstruct id: "", name: "", theme: "", black: false, white: false, red: false, green: false, blue: false, colorless: false

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Deck

  def feed(%Event{id: _event_id, tags: [:create, :deck], data: %{name: name, player_id: player_id} = data}) do
    case Data.state_exists?("Player", player_id) do
      false ->
        #Return
        [Event.new([:deck, :create, :fail], %{cause: "player not found", data: data})]
      true ->
        #Create state
        #The initialization is the only state change outside of a process
        deck_state = build_state(Id.hrid(name), data)
        #Save state
        :ok = Data.save_state(__ENV__.module, deck_state.id, deck_state)
        #Start genserver
        GenServer.start(Metr.Deck, deck_state, [name: Data.genserver_id(__ENV__.module, deck_state.id)])

        #Return
        [Event.new([:deck, :created], %{id: deck_state.id, player_id: player_id})]
    end
  end

  def feed(%Event{id: _event_id, tags: [:read, :deck] = tags, data: %{deck_id: id}}) do
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
      GenServer.start(Metr.Deck, current_state, [name: Data.genserver_id(__ENV__.module, id)])
    end
  end


  defp build_state(id, %{name: name, player_id: _player_id, colors: colors}) do
    %Deck{id: id, name: name}
    |> apply_colors(colors)
  end

  defp build_state(id, %{name: name, player_id: _player_id}) do
    %Deck{id: id, name: name}
  end


  defp apply_colors(%Deck{} = deck, colors) when is_list(colors) do
    Enum.reduce(colors, deck, fn c,d -> apply_color(c, d) end)
  end

  defp apply_color(color, %Deck{} = deck) when is_atom(color) do
    Map.put(deck, color, true)
  end



  ## gen
  @impl true
  def init(state) do
    {:ok, state}
  end


  @impl true
  def handle_call(%{tags: [:read, :deck]}, _from, state) do
    #Reply
    {:reply, state, state}
  end
end

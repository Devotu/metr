defmodule Metr.Modules.State do
  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.Player

  @doc """
  Passes the input to the appropriate module for creation.
  The idea is to collect all boiler plate in one place and let each module focus on its specifics
  """
  def feed(
        %Event{id: _event_id, keys: [:create, module], data: %{id: id, input: input}} = event,
        repp
      ) do

    process_name = Data.genserver_id(id, module) |> IO.inspect(label: "state - process name")
    target_module = select_target_module(module) |> IO.inspect(label: "state - process module")

    IO.inspect id, label: "state - specified id"
    IO.inspect input, label: "state - input"

    case GenServer.start(target_module, {id, input, event}, name: process_name) do
      {:ok, _pid} ->
        [Event.new([module, :created, repp], %{out: id})]
      {:error, e} ->
        [Event.error_to_event(e, repp)]
    end
  end


  @doc """
  Generates a guid and runs corresponding feed with it
  """
  def feed(
        %Event{id: _event_id, keys: [:create, _module], data: input} = event,
        repp
      ) do

    id = Id.guid() |> IO.inspect(label: "state - id")
    id_input = %{id: id, input: input}
    event_with_specific_id = Map.put(event, :data, id_input)
    feed(event_with_specific_id, repp)
  end

  def feed(_event, _repp) do
    []
  end

  @doc """
  Fetches the actual corresponding module for use in further functions
  """
  defp select_target_module(module_atom) when is_atom(module_atom) do
    case module_atom do
      :player -> Player
      :deck -> Deck
      :game -> Game
      :match -> Match
      :result -> Result
      :tag -> Tag
      _ -> {:error, "#{Kernel.inspect(module_atom)} is not a valid atom selecting module"}
    end
  end
end

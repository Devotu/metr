defmodule Metr.Modules.State do
  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result

  @doc """
  Passes the input to the appropriate module for creation.
  The idea is to collect all boiler plate in one place and let each module focus on its specifics
  """
  def feed(
        %Event{id: _event_id, keys: [:create, module], data: %{id: id, input: input}} = event,
        repp
      ) do

    process_name = Data.genserver_id(id, module) #|> IO.inspect(label: "state - process name")
    target_module = select_target_module(module) #|> IO.inspect(label: "state - process module")

    IO.inspect id, label: "state - specified id"
    IO.inspect input, label: "state - input"

    case GenServer.start(target_module, {id, input, event}, name: process_name) do
      {:ok, _pid} ->
        [Event.new([module, :created, repp], %{out: id})]
        |> IO.inspect(label: "state - ok")
      {:error, e} ->
        [Event.error_to_event(e, repp)]
        |> IO.inspect(label: "state - error")
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

  def feed(%Event{keys: [:read, module], data: %{id: id}}, repp) do
    case read(id, module) do
      {:error, e} ->
        [Event.error_to_event(e, repp)]
      state ->
        [Event.new([module, :read, repp], %{out: state})]
    end
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

  def read(id, module) when is_atom(module) and is_bitstring(id) do
    {:ok, id, module}
    |> is_valid_id()
    |> ready_process()
    |> recall()
  end

  defp is_valid_id({:error, e}), do: {:error, e}
  defp is_valid_id({:ok, id, module}) when is_atom(module) and is_bitstring(id) do
    case Data.state_exists?(module, id) do
      true -> {:ok, id, module}
      false -> {:error, "#{module |> Atom.to_string |> String.capitalize()} #{id} not found"}
    end
  end

  defp ready_process({:error, e}), do: {:error, e}
  defp ready_process({:ok, id, module}) do
    # Is running?
    case {GenServer.whereis(Data.genserver_id(module, id)),
          Data.state_exists?(module, id)} do
      {nil, true} ->
        start_process({:ok, id, module})

      {nil, false} ->
        {:error, :no_such_id}

      _ ->
        {:ok, id, module}
    end
  end

  defp start_process({:error, e}), do: {:error, e}
  defp start_process({:ok, id, module}) do
    # Get state
    current_state =
      Data.recall_state(module, id)

    case GenServer.start(select_target_module(module), current_state,
           name: Data.genserver_id(module, id)
         ) do
      {:ok, _pid} -> {:ok, id, module}
      {:error, cause} -> {:error, cause}
      x -> {:error, inspect(x)}
    end
  end

  defp recall({:error, e}), do: {:error, e}
  defp recall({:ok, id, entity}) when is_atom(entity) and is_bitstring(id) do
    GenServer.call(Data.genserver_id(entity, id), %{
      keys: [:read, entity]
    })
  end
end
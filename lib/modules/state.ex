defmodule Metr.Modules.State do
  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result

  @max_read_attempts 3
  @timeout_ms 32

  @doc """
  Passes the input to the appropriate module for creation.
  The idea is to collect all boiler plate in one place and let each module focus on its specifics
  """
  def feed(
        %Event{id: _event_id, keys: [:create, module], data: %{id: id, input: input}} = event,
        repp
      ) do

    process_name = Data.genserver_id(id, module)
    target_module = select_target_module(module)

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

  def feed(%Event{keys: [:list, module], data: data}, repp) when %{} == data do
    states = module
      |> Data.list_ids()
      |> Enum.map(fn id -> read(id, module) end)

    [Event.new([module, :list, repp], %{out: states})]
  end

  def feed(%Event{id: _event_id, keys: [:read, :log, module], data: %{id: id}}, repp) when is_atom(module) do
    events = Data.read_log_by_id(id, module)
    [Event.new([module, :read, repp], %{out: events})]
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

  @doc """
  Reads the entity through its own module genserver
  """
  def read(id, module) when is_atom(module) and is_bitstring(id) do
    {id, module}
    |> read_robust()
  end

  defp read_robust({:error, e}), do: {:error, e}
  defp read_robust({id, module}), do: read_robust({id, module}, 0)
  defp read_robust({id, module}, @max_read_attempts), do: read_robust({:error, "#{module} #{id} not found"})
  defp read_robust({id, module}, attempt) do
    :timer.sleep(attempt * @timeout_ms)
    IO.inspect attempt * @timeout_ms, label: "state read slept"

    result = {id, module}
      |> is_valid_id()
      |> ready_process()
      |> recall()

    case result do
      {:error, _e} -> read_robust({id, module}, attempt + 1)
      x -> x
    end
  end

  @doc """
  Checks if the id currently seems to be worth working with
  ie it has some state
  TODO Is this really neccessary? Does that not belong to the process?
  """
  defp is_valid_id({:error, e}), do: {:error, e}
  defp is_valid_id({id, module}) when is_atom(module) and is_bitstring(id) do
    case Data.state_exists?(module, id) do
      true -> {id, module}
      false -> {:error, "#{module |> Atom.to_string |> String.capitalize()} #{id} not found"}
    end
  end

  @doc """
  Checks if the given process is already running and if it has state
  If not starts it up
  TODO Is the state check really neccessary? Does that not belong to the process?
  """
  defp ready_process({:error, e}), do: {:error, e}
  defp ready_process({id, module}) do
    # Is running?
    case {GenServer.whereis(Data.genserver_id(module, id)),
          Data.state_exists?(module, id)} do
      {nil, true} ->
        start_process({id, module})

      {nil, false} ->
        {:error, :no_such_id}

      _ ->
        {id, module}
    end
  end

  @doc """
  Starts the given process
  """
  defp start_process({:error, e}), do: {:error, e}
  defp start_process({id, module}) do
    # Get state
    current_state =
      Data.recall_state(module, id)

    case GenServer.start(select_target_module(module), current_state,
           name: Data.genserver_id(module, id)
         ) do
      {:ok, _pid} -> {id, module}
      {:error, cause} -> {:error, cause}
      x -> {:error, inspect(x)}
    end
  end

  @doc """
  Calls the corresponding process and asks it to return its state
  """
  defp recall({:error, e}), do: {:error, e}
  defp recall({id, module}) when is_atom(module) and is_bitstring(id) do
    GenServer.call(Data.genserver_id(module, id), %{
      keys: [:read, module]
    })
  end

  @doc """
  Calls the corresponding process with a notice that it should concider the given change
  """
  def update(id, module, event) when is_atom(module) and is_bitstring(id) do
    {id, module}
    |> is_valid_id()
    |> ready_process()
    |> alter(event)
  end

  defp alter({:error, e},_event), do: {:error, e}
  defp alter({id, entity}, event) do
    # Call update
    GenServer.call(Data.genserver_id(entity, id), event)
  end

  def exist?(id, module) when is_atom(module) do
    Data.state_exists?(module, id)
  end
end

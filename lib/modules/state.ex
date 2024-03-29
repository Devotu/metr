defmodule Metr.Modules.State do
  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Util
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.State
  alias Metr.Modules.Tag

  @max_read_attempts 8
  @timeout_ms 16

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
      |> Task.async_stream(fn id -> read(id, module) end)
      |> Enum.to_list()
      |> Enum.map(fn {:ok, s} -> s end)

    [Event.new([module, :list, repp], %{out: states})]
  end

  def feed(%Event{id: _event_id, keys: [:read, :log, module], data: %{id: id}}, repp) when is_atom(module) do
    events = Data.read_log_by_id(id, module)
    [Event.new([module, :read, repp], %{out: events})]
  end

  def feed(%Event{id: _event_id, keys: [:rerun, module], data: %{id: id}}, repp) when is_atom(module) do
    case rerun_log({id, module}) do
      {:error, e} ->
        [Event.error_to_event(e, repp)]
      out ->
        [Event.new([module, :reran, repp], %{out: out})]
    end
  end

  def feed(%Event{id: _event_id, keys: [tagged_module, :tagged], data: %{id: tagged_id}} = event, repp) when is_atom(tagged_module) do
    State.update(tagged_id, tagged_module, event)
    |> Event.message_to_event([tagged_module, :altered, repp])
    |> List.wrap()
  end

  def feed(_event, _repp) do
    []
  end


  def create(id, module, %Event{} = event, repp) do
    process_name = Data.genserver_id(id, module)
    target_module = select_target_module(module)

    case GenServer.start(target_module, event, name: process_name) do
      {:ok, _pid} ->
        [Event.new([module, :created, repp], %{out: id})]
      {:error, e} ->
        [Event.error_to_event(e, repp)]
    end
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

    if attempt != 0 do
      :timer.sleep(attempt * @timeout_ms)
      IO.inspect {id, module}, label: "state read sleep"
      IO.inspect attempt * @timeout_ms, label: "state read slept"
    end

    result = {id, module}
      |> is_valid_id()
      |> ready_process()
      |> recall()

    case result do
      {:error, e} ->
        read_robust({id, module}, attempt + 1)
      x ->
        x
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
    Data.log_exists?(module, id)
  end

  defp rerun_log({id, module}) do
    {id, module}
    |> has_log()
    |> stop()
    |> wipe_current()
    |> feed_log()
  end

  defp has_log({:error, e}), do: {:error, e}
  defp has_log({id, module}) do
    Data.log_exists?(module, id)
    case Data.log_exists?(module, id) do
      false ->
        {:error, "#{module} #{id} has no log"}
      _ ->
        {id, module}
    end
  end

  defp wipe_current({:error, e}), do: {:error, e}
  defp wipe_current({id, module}) do
    case Data.wipe_state(id, module) do
      {:error, e} ->
        {:error, e}
      _ ->
        {id, module}
    end
  end

  defp feed_log({:error, e}), do: {:error, e}
  defp feed_log({id, module}) do
    mod = select_target_module(module)
    result = Data.read_log_by_id(id, module)
      |> Enum.uniq()
      |> Enum.map(fn e -> feed_event(mod, e) end)
      |> Enum.filter(fn r -> Util.is_error?(r) end)
      |> List.first()

      case result do
        {:error, e} ->
          {:error, e}
        _ ->
          :ok
      end
  end

  defp feed_event(reciever, event) do
    reciever.feed(event, nil)
  end

  def stop({id, module}) do
    case is_running?({id, module}) do
      {:error, e} ->
        IO.inspect e, label: "state - stop e"
        {:error, e}
      true ->
        IO.inspect id, label: "state - stoping"
        Data.genserver_id(module, id) |> GenServer.stop() |> IO.inspect(label: "state - stopped")
        {id, module}
      false ->
        IO.inspect id, label: "state - not running"
        {id, module}
    end
  end

  defp is_running?({:error, e}), do: {:error, e}
  defp is_running?({id, entity}) do
    case GenServer.whereis(Data.genserver_id(entity, id)) do
      nil ->
        false
      _pid ->
        true
    end
  end
end

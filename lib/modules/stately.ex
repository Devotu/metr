defmodule Metr.Modules.Stately do
  use GenServer

  alias Metr.Data
  alias Metr.Event
  alias Metr.Util

  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Tag

  @valid_name_length 32

  ## feed
  def feed(%Event{keys: [:read, module_atom], data: %{id: id}}, repp) do
    module = select_module(module_atom)
    state = read(id, module)
    [Event.new([module_atom, :read, repp], %{out: state})]
  end

  def feed(%Event{keys: [:read, :log]}, _repp), do: []

  def feed(%Event{keys: [:read, module_atom], data: data}, repp) when is_map(data) do
    module = select_module(module_atom)
    id_name = module_id(module_atom)
    id = Map.get(data, id_name, {:error, "key not found"})

    case id do
      {:error, e} ->
        out_to_event(e, module, [module_atom, :error, repp])

      _ ->
        state = read(id, module)
        [Event.new([module_atom, :read, repp], %{out: state})]
    end
  end

  def feed(%Event{keys: [:list, :format]}, _repp), do: []

  def feed(%Event{keys: [:list, module_atom], data: data}, repp) when %{} == data do
    module = select_module(module_atom)

    states =
      Data.list_ids(module)
      |> Enum.map(fn id -> read(id, module) end)

    [Event.new([module_atom, :list, repp], %{out: states})]
  end

  def feed(
        %Event{id: _event_id, keys: [:rerun, module_atom], data: %{id: id}},
        repp
      ) do
    module = select_module(module_atom)

    [
      rerun(id, module)
      |> out_to_event(module, [:reran, repp])
    ]
  end

  def feed(_event, _orepp) do
    []
  end

  ## gen
  ## currently only existing states
  @impl true
  def init({id, module}) do
    validation_result =
      {:ok, id, module}
      |> validate_module()
      |> verified_id()

    case validation_result do
      {:ok, id, module} ->
        state = Data.recall_state(module, id)
        {:ok, state}

      {:error, e} ->
        {:stop, e}
    end
  end

  @impl true
  def handle_call(%{keys: [:read, :player]}, _from, state) do
    {:reply, state, state}
  end

  ## public
  def exist?(id, module) when is_atom(module) do
    {:ok, id, module}
    |> validate_module()
    |> module_has_state()
  end

  def read(id, module) when is_atom(module) and is_bitstring(id) do
    {:ok, id, module}
    |> validate_module()
    |> IO.inspect(label: "stately - module")
    |> verified_id()
    |> IO.inspect(label: "stately - id")
    |> ready_process()
    |> IO.inspect(label: "stately - process")
    |> recall()
  end

  def ready(id, module) do
    result =
      {:ok, id, module}
      |> validate_module()
      |> verified_id()
      |> ready_process()

    case result do
      {:ok, _id, _module} -> {:ok}
      x -> x
    end
  end

  defp is_running?({:error, e}), do: {:error, e}

  defp is_running?({:ok, id, module}) do
    case GenServer.whereis(Data.genserver_id(module, id)) do
      nil -> false
      _pid -> {:ok, id, module}
    end
  end

  def stop(id, module) do
    result =
      {:ok, id, module}
      |> validate_module()
      |> is_running?()

    case result do
      {:error, e} -> {:error, e}
      {:ok, _id, _module} -> Data.genserver_id(module, id) |> GenServer.stop()
      x -> x
    end
  end

  def update(id, module, keys, data, event) when is_atom(module) and is_bitstring(id) do
    {:ok, id, module}
    |> validate_module()
    |> verified_id()
    |> ready_process()
    |> alter(keys, data, event)
  end

  def out_to_event({:ok, msg}, module, keys), do: out_to_event(msg, module, keys)

  def out_to_event(msg, module, keys) when is_atom(module) do
    Event.new([module] ++ keys, %{out: msg})
  end

  def module_to_name(module) do
    module
    |> Kernel.inspect()
    |> String.split(".")
    |> List.last()
    |> String.replace("\"", "")
  end

  def rerun(id, module) do
    {:ok, id, module}
    |> validate_module()
    |> rerun_from_log()
  end

  def is_accepted_name({:error, e}, _name), do: {:error, e}
  def is_accepted_name(:ok, name), do: is_accepted_name(name)
  def is_accepted_name(""), do: {:error, "name cannot be empty"}
  def is_accepted_name(name) when is_bitstring(name) do
    case String.length(name) < @valid_name_length do
      true -> :ok
      false -> {:error, "name to long"}
    end
  end

  def is_accepted_name(name) when is_nil(name), do: {:error, "name cannot be nil"}
  def is_accepted_name(_name), do: {:error, "name must be string"}

  def create(module, %{id: id} = state, %Event{} = event)
      when is_atom(module) and is_struct(state) do
    creation_result =
      {:ok, id, module}
      |> validate_module()
      |> verify_unique()
      |> store_state(state, event)
      |> start_new(state)

    case creation_result do
      {:ok, _id, _module} ->
        {:ok, id}

      {:error, e} ->
        {:error, e}
    end
  end

  def create(module, _state) when is_bitstring(module),
    do: {:error, "state must be struct"}

  def module_id(module_atom) when is_atom(module_atom) do
    case module_atom do
      :player -> :player_id
      :deck -> :deck_id
      :game -> :game_id
      :match -> :match_id
      :result -> :result_id
      :tag -> :tag_id
      _ -> {:error, "#{Kernel.inspect(module_atom)} is not a valid atom selecting id name"}
    end
  end
  def module_id(module) when is_atom(module) do
    module
    |> module_id()
  end

  def apply_event(id, module_qualifier, %Event{} = event) when is_bitstring(id) and is_atom(module_qualifier) do
    module = select_module(module_qualifier)
    module.feed(event, nil)
  end

  ## private {:ok, id, module} / {:error, e}
  defp verify_unique({:error, e}), do: {:error, e}

  defp verify_unique({:ok, id, module}) when is_atom(module) and is_bitstring(id) do
    case exist?(id, module) do
      false -> {:ok, id, module}
      true -> {:error, "name already in use"}
    end
  end

  defp store_state({:error, e}), do: {:error, e}

  defp store_state({:ok, id, module}, state, %Event{} = event) do
    case Data.save_state_with_log(module, id, state, event) do
      :ok -> {:ok, id, module}
      _ -> {:error, "could not save state"}
    end
  end

  defp start_new({:error, e}), do: {:error, e}

  defp start_new({:ok, id, module}, state) do
    process_name = Data.genserver_id(module, id)

    case GenServer.start(select_module(module), state, name: process_name) do
      {:ok, _pid} ->
        {:ok, id, module}

      {:error, e} ->
        {:error, e}
    end
  end

  defp rerun_from_log({:error, e}), do: {:error, e}

  defp rerun_from_log({:ok, id, module}) do
    {:ok, id, module}
    |> wipe_state()
    |> run_log()
    |> conclude_rerun()
    |> select_rerun_return()
  end

  defp wipe_state({:error, e}), do: {:error, e}

  defp wipe_state({:ok, id, module}) do
    case Data.wipe_state([id], module) do
      :ok -> {:ok, id, module}
      _ -> {:error, "Failed to wipe current state of #{module} #{id}"}
    end
  end

  defp run_log({:error, e}), do: {:error, e}

  defp run_log({:ok, id, module}) do
    module = select_module(module)
    stop(id, module)

    case Data.read_log_by_id(id, module) do
      {:error, :not_found} ->
        {:error, "Log of #{module} #{id} not found"}

      log ->
        log
        |> Util.uniq()
        |> Enum.map(fn e -> module.feed(e, nil) end)
    end
  end

  defp conclude_rerun({:error, e}), do: {:error, e}

  defp conclude_rerun(feedback_events) do
    feedback_events
    |> List.flatten()
    |> Enum.filter(fn e -> Enum.member?(e.keys, :error) end)
  end

  defp select_rerun_return({:error, e}), do: {:error, e}
  defp select_rerun_return([]), do: :ok

  defp select_rerun_return(error_events) when is_list(error_events),
    do: {:error, Kernel.inspect(error_events)}

  defp return_result({:error, e}), do: {:error, e}
  defp return_result({:ok, _id, _module}), do: :ok

  defp select_module(module) when is_atom(module) do
    case module do
      :player -> Player
      :deck -> Deck
      :game -> Game
      :match -> Match
      :result -> Result
      :tag -> Tag
      _ -> {:error, "#{Kernel.inspect(module)} is not a valid atom selecting module"}
    end
  end

  defp select_module_struct(module) when is_atom(module) do
    case module do
      :player -> %Player{}
      :deck -> %Deck{}
      :game -> %Game{}
      :match -> %Match{}
      :result -> %Result{}
      :tag -> %Tag{}
      _ -> {:error, "#{module} is not a valid module selecting struct"}
    end
  end

  defp validate_module({:error, e}), do: {:error, e}

  defp validate_module({:ok, id, module}) when is_atom(module) and is_bitstring(id) do
    case module do
      :player -> {:ok, id, module}
      :deck -> {:ok, id, module}
      :game -> {:ok, id, module}
      :match -> {:ok, id, module}
      :result -> {:ok, id, module}
      :tag -> {:ok, id, module}
      _ -> {:error, "#{module} is not a valid module name"}
    end
  end

  defp module_has_state({:error, e}), do: {:error, e}

  defp module_has_state({:ok, id, module}) when is_atom(module) and is_bitstring(id) do
    Data.state_exists?(module, id)
  end

  defp verified_id({:error, e}), do: {:error, e}

  defp verified_id({:ok, id, module}) when is_atom(module) and is_bitstring(id) do
    case module_has_state({:ok, id, module}) do
      true -> {:ok, id, module}
      false -> {:error, "#{module} #{id} not found"}
    end
  end

  defp recall({:error, e}), do: {:error, e}

  defp recall({:ok, id, module}) when is_atom(module) and is_bitstring(id) do
    GenServer.call(Data.genserver_id(module, id), %{
      keys: [:read, module]
    })
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

  defp start_process({:ok, id, module}) do
    # Get state
    current_state =
      Map.merge(select_module_struct(module), Data.recall_state(module, id))

    case GenServer.start(select_module(module), current_state,
           name: Data.genserver_id(module, id)
         ) do
      {:ok, _pid} -> {:ok, id, module}
      {:error, cause} -> {:error, cause}
      x -> {:error, inspect(x)}
    end
  end

  defp alter({:error, e}, _keys, _data, _event), do: {:error, e}

  defp alter({:ok, id, module}, keys, data, event) do
    # Call update
    GenServer.call(Data.genserver_id(module, id), %{keys: keys, data: data, event: event})
  end
end

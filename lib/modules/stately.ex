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
  def feed(%Event{keys: [:read, entity], data: %{id: id}}, repp) do
    state = read(id, entity)
    [Event.new([entity, :read, repp], %{out: state})]
  end

  def feed(%Event{keys: [:read, :log]}, _repp), do: []

  def feed(%Event{keys: [:read, entity], data: data}, repp) when is_map(data) do
    module = select_module(entity)
    id_name = entity_id(entity)
    id = Map.get(data, id_name, {:error, "key not found"})

    case id do
      {:error, e} ->
        out_to_event(e, entity, [entity, :error, repp])

      _ ->
        state = read(id, entity)
        [Event.new([entity, :read, repp], %{out: state})]
    end
  end

  def feed(%Event{keys: [:list, :format]}, _repp), do: []

  def feed(%Event{keys: [:list, entity], data: data}, repp) when %{} == data do
    states = entity
      |> Data.list_ids()
      |> Enum.map(fn id -> read(id, entity) end)

    [Event.new([entity, :list, repp], %{out: states})]
  end

  def feed(
        %Event{id: _event_id, keys: [:rerun, entity], data: %{id: id}},
        repp
      ) do
    [
      rerun(id, entity)
      |> out_to_event(entity, [:reran, repp])
    ]
  end

  def feed(_event, _orepp) do
    []
  end

  ## gen
  ## currently only existing states
  @impl true
  def init({id, entity}) do
    validation_result =
      {:ok, id, entity}
      |> validate_entity()
      |> verified_id()

    case validation_result do
      {:ok, id, entity} ->
        state = Data.recall_state(entity, id)
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
  def exist?(id, entity) when is_atom(entity) do
    {:ok, id, entity}
    |> validate_entity()
    |> entity_has_state()
  end

  def read(id, entity) when is_atom(entity) and is_bitstring(id) do
    {:ok, id, entity}
    |> validate_entity()
    |> IO.inspect(label: "stately - entity")
    |> verified_id()
    |> IO.inspect(label: "stately - id")
    |> ready_process()
    |> IO.inspect(label: "stately - process")
    |> recall()
  end

  def ready(id, entity) do
    result =
      {:ok, id, entity}
      |> validate_entity()
      |> verified_id()
      |> ready_process()

    case result do
      {:ok, _id, _entity} -> {:ok}
      x -> x
    end
  end

  defp is_running?({:error, e}), do: {:error, e}

  defp is_running?({:ok, id, entity}) do
    case GenServer.whereis(Data.genserver_id(entity, id)) do
      nil -> false
      _pid -> {:ok, id, entity}
    end
  end

  def stop(id, entity) do
    result =
      {:ok, id, entity}
      |> validate_entity()
      |> is_running?()

    case result do
      {:error, e} -> {:error, e}
      {:ok, _id, _entity} -> Data.genserver_id(entity, id) |> GenServer.stop()
      x -> x
    end
  end

  def update(id, entity, keys, data, event) when is_atom(entity) and is_bitstring(id) do
    {:ok, id, entity}
    |> validate_entity()
    |> verified_id()
    |> ready_process()
    |> alter(keys, data, event)
  end

  def out_to_event({:ok, msg}, entity, keys), do: out_to_event(msg, entity, keys)

  def out_to_event(msg, entity, keys) when is_atom(entity) do
    Event.new([entity] ++ keys, %{out: msg})
  end

  def entity_to_name(entity) do
    entity
    |> Kernel.inspect()
    |> String.split(".")
    |> List.last()
    |> String.replace("\"", "")
  end

  def rerun(id, entity) do
    {:ok, id, entity}
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

  def create(entity, %{id: id} = state, %Event{} = event)
      when is_atom(entity) and is_struct(state) do
    creation_result =
      {:ok, id, entity}
      |> validate_entity()
      |> verify_unique()
      |> store_state(state, event)
      |> start_new(state)

    case creation_result do
      {:ok, _id, _entity} ->
        {:ok, id}

      {:error, e} ->
        {:error, e}
    end
  end

  def create(entity, _state) when is_bitstring(entity),
    do: {:error, "state must be struct"}

  def entity_id(entity) when is_atom(entity) do
    case entity do
      :player -> :player_id
      :deck -> :deck_id
      :game -> :game_id
      :match -> :match_id
      :result -> :result_id
      :tag -> :tag_id
      _ -> {:error, "#{Kernel.inspect(entity) |> String.capitalize()} is not a valid atom selecting id name"}
    end
  end
  def entity_id(entity) when is_atom(entity) do
    entity
    |> entity_id()
  end

  def apply_event(id, entity_qualifier, %Event{} = event) when is_bitstring(id) and is_atom(entity_qualifier) do
    module = select_module(entity_qualifier)
    module.feed(event, nil)
  end

  ## private {:ok, id, entity} / {:error, e}
  defp verify_unique({:error, e}), do: {:error, e}

  defp verify_unique({:ok, id, entity}) when is_atom(entity) and is_bitstring(id) do
    case exist?(id, entity) do
      false -> {:ok, id, entity}
      true -> {:error, "name already in use"}
    end
  end

  defp store_state({:error, e}), do: {:error, e}

  defp store_state({:ok, id, entity}, state, %Event{} = event) do
    case Data.save_state_with_log(entity, id, state, event) do
      :ok -> {:ok, id, entity}
      _ -> {:error, "could not save state"}
    end
  end

  defp start_new({:error, e}), do: {:error, e}

  defp start_new({:ok, id, entity}, state) do
    process_name = Data.genserver_id(entity, id)

    case GenServer.start(select_module(entity), state, name: process_name) do
      {:ok, _pid} ->
        {:ok, id, entity}

      {:error, e} ->
        {:error, e}
    end
  end

  defp rerun_from_log({:error, e}), do: {:error, e}

  defp rerun_from_log({:ok, id, entity}) do
    IO.inspect(entity, label: "stately rerun entity")
    {:ok, id, entity}
    |> wipe_state()
    |> run_log()
    |> conclude_rerun()
    |> select_rerun_return()
  end

  defp wipe_state({:error, e}), do: {:error, e}

  defp wipe_state({:ok, id, entity}) do
    case Data.wipe_state([id], entity) do
      :ok -> {:ok, id, entity}
      _ -> {:error, "Failed to wipe current state of #{entity} #{id}"}
    end
  end

  defp run_log({:error, e}), do: {:error, e}

  defp run_log({:ok, id, entity}) when is_atom(entity) and is_bitstring(id) do
    IO.inspect(entity, label: "stately entity")
    module = select_module(entity)
    stop(id, entity)

    case Data.read_log_by_id(id, entity) do
      {:error, :not_found} ->
        {:error, "Log of #{entity |> Atom.to_string()} #{id} not found"}

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
  defp return_result({:ok, _id, _entity}), do: :ok

  defp select_module(entity) when is_atom(entity) do
    case entity do
      :player -> Player
      :deck -> Deck
      :game -> Game
      :match -> Match
      :result -> Result
      :tag -> Tag
      _ -> {:error, "#{Kernel.inspect(entity)} is not a valid atom selecting entity"}
    end
  end

  defp select_module_struct(entity) when is_atom(entity) do
    case entity do
      :player -> %Player{}
      :deck -> %Deck{}
      :game -> %Game{}
      :match -> %Match{}
      :result -> %Result{}
      :tag -> %Tag{}
      _ -> {:error, "#{entity} is not a valid entity selecting struct"}
    end
  end

  defp validate_entity({:error, e}), do: {:error, e}

  defp validate_entity({:ok, id, entity}) when is_atom(entity) and is_bitstring(id) do
    case entity do
      :player -> {:ok, id, entity}
      :deck -> {:ok, id, entity}
      :game -> {:ok, id, entity}
      :match -> {:ok, id, entity}
      :result -> {:ok, id, entity}
      :tag -> {:ok, id, entity}
      _ -> {:error, "#{entity} is not a valid entity name"}
    end
  end

  defp entity_has_state({:error, e}), do: {:error, e}

  defp entity_has_state({:ok, id, entity}) when is_atom(entity) and is_bitstring(id) do
    Data.state_exists?(entity, id)
  end

  defp verified_id({:error, e}), do: {:error, e}

  defp verified_id({:ok, id, entity}) when is_atom(entity) and is_bitstring(id) do
    case entity_has_state({:ok, id, entity}) do
      true -> {:ok, id, entity}
      false -> {:error, "#{entity |> Atom.to_string |> String.capitalize()} #{id} not found"}
    end
  end

  defp recall({:error, e}), do: {:error, e}

  defp recall({:ok, id, entity}) when is_atom(entity) and is_bitstring(id) do
    GenServer.call(Data.genserver_id(entity, id), %{
      keys: [:read, entity]
    })
  end

  defp ready_process({:error, e}), do: {:error, e}

  defp ready_process({:ok, id, entity}) do
    # Is running?
    case {GenServer.whereis(Data.genserver_id(entity, id)),
          Data.state_exists?(entity, id)} do
      {nil, true} ->
        start_process({:ok, id, entity})

      {nil, false} ->
        {:error, :no_such_id}

      _ ->
        {:ok, id, entity}
    end
  end

  defp start_process({:ok, id, entity}) do
    # Get state
    current_state =
      Map.merge(select_module_struct(entity), Data.recall_state(entity, id))

    case GenServer.start(select_module(entity), current_state,
           name: Data.genserver_id(entity, id)
         ) do
      {:ok, _pid} -> {:ok, id, entity}
      {:error, cause} -> {:error, cause}
      x -> {:error, inspect(x)}
    end
  end

  defp alter({:error, e}, _keys, _data, _event), do: {:error, e}

  defp alter({:ok, id, entity}, keys, data, event) do
    # Call update
    GenServer.call(Data.genserver_id(entity, id), %{keys: keys, data: data, event: event})
  end
end

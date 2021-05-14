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
    module_name = select_module_name(module_atom)
    state = read(id, module_name)
    [Event.new([module_atom, :read, repp], %{out: state})]
  end

  def feed(%Event{keys: [:read, :log]}, _repp), do: []

  def feed(%Event{keys: [:read, module_atom], data: data}, repp) when is_map(data) do
    module_name = select_module_name(module_atom)
    id_name = module_id(module_atom)
    id = Map.get(data, id_name, {:error, "key not found"})

    case id do
      {:error, e} ->
        out_to_event(e, module_name, [module_atom, :error, repp])

      _ ->
        state = read(id, module_name)
        [Event.new([module_atom, :read, repp], %{out: state})]
    end
  end

  def feed(%Event{keys: [:list, :format]}, _repp), do: []

  def feed(%Event{keys: [:list, module_atom], data: data}, repp) when %{} == data do
    module_name = select_module_name(module_atom)
    module_plurals = module_plural(module_atom)

    states =
      Data.list_ids(module_name)
      |> Enum.map(fn id -> read(id, module_name) end)

    data = Map.put(%{}, module_plurals, states)

    [Event.new([module_plurals, repp], data)]
  end

  def feed(
        %Event{id: _event_id, keys: [:rerun, module_atom], data: %{id: id}},
        repp
      ) do
    module_name = select_module_name(module_atom)

    [
      rerun(id, module_name)
      |> out_to_event(module_name, [:reran, repp])
    ]
  end

  def feed(_event, _orepp) do
    []
  end

  ## gen
  ## currently only existing states
  @impl true
  def init({id, module_name}) do
    validation_result =
      {:ok, id, module_name}
      |> validate_module()
      |> verified_id()

    case validation_result do
      {:ok, id, module_name} ->
        state = Data.recall_state(module_name, id)
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
  def exist?(id, module_atom) when is_atom(module_atom) do
    {:ok, id, select_module_name(module_atom)}
    |> validate_module()
    |> module_has_state()
  end

  def exist?(id, module_name) do
    {:ok, id, module_name}
    |> validate_module()
    |> module_has_state()
  end

  def read(id, module) when is_bitstring(id) and is_atom(module) do
    {:ok, id, select_module_name(module)}
    |> verified_id()
    |> ready_process()
    |> recall()
  end

  def read(id, module_name) do
    {:ok, id, module_name}
    |> validate_module()
    |> verified_id()
    |> ready_process()
    |> recall()
  end

  def ready(id, module_name) do
    result =
      {:ok, id, module_name}
      |> validate_module()
      |> verified_id()
      |> ready_process()

    case result do
      {:ok, _id, _module_name} -> {:ok}
      x -> x
    end
  end

  defp is_running?({:error, e}), do: {:error, e}

  defp is_running?({:ok, id, module_name}) do
    case GenServer.whereis(Data.genserver_id(module_name, id)) do
      nil -> false
      _pid -> {:ok, id, module_name}
    end
  end

  def stop(id, module_name) do
    result =
      {:ok, id, module_name}
      |> validate_module()
      |> is_running?()

    case result do
      {:error, e} -> {:error, e}
      {:ok, _id, _module_name} -> Data.genserver_id(module_name, id) |> GenServer.stop()
      x -> x
    end
  end

  def update(id, module_name, keys, data, event) do
    {:ok, id, module_name}
    |> validate_module()
    |> verified_id()
    |> ready_process()
    |> alter(keys, data, event)
  end

  def out_to_event({:ok, msg}, module_name, keys), do: out_to_event(msg, module_name, keys)

  def out_to_event(msg, module_name, keys) when is_bitstring(module_name) do
    Event.new([select_module_atom(module_name)] ++ keys, %{out: msg})
  end

  def module_to_name(module_name) do
    module_name
    |> Kernel.inspect()
    |> String.split(".")
    |> List.last()
    |> String.replace("\"", "")
  end

  def rerun(id, module_name) do
    {:ok, id, module_name}
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

  def create(module_name, %{id: id} = state, %Event{} = event)
      when is_bitstring(module_name) and is_struct(state) do
    creation_result =
      {:ok, id, module_name}
      |> validate_module()
      |> verify_unique()
      |> store_state(state, event)
      |> start_new(state)

    case creation_result do
      {:ok, _id, _module_name} ->
        {:ok, id}

      {:error, e} ->
        {:error, e}
    end
  end

  def create(module_name, _state) when is_bitstring(module_name),
    do: {:error, "state must be struct"}

  def select_module_name(module_atom) when is_atom(module_atom) do
    case module_atom do
      :player -> "Player"
      :deck -> "Deck"
      :game -> "Game"
      :match -> "Match"
      :result -> "Result"
      :tag -> "Tag"
      _ -> {:error, "#{Kernel.inspect(module_atom)} is not a valid atom selecting module"}
    end
  end

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
  def module_id(module_name) when is_bitstring(module_name) do
    module_name
    |> select_module_atom()
    |> module_id()
  end

  def module_plural(module_atom) when is_atom(module_atom) do
    case module_atom do
      :player -> :players
      :deck -> :decks
      :game -> :games
      :match -> :matches
      :result -> :results
      :tag -> :tags
      _ -> {:error, "#{Kernel.inspect(module_atom)} is not a valid atom selecting plural form"}
    end
  end

  def select_module_atom(module_name) when is_bitstring(module_name) do
    case String.downcase(module_name) do
      "player" -> :player
      "deck" -> :deck
      "game" -> :game
      "match" -> :match
      "result" -> :result
      "tag" -> :tag
      _ -> {:error, "#{module_name} is not a valid module name selecting atom"}
    end
  end

  def apply_event(id, module_qualifier, %Event{} = event) when is_bitstring(id) and is_atom(module_qualifier) do
    module = select_module(module_qualifier)
    module.feed(event, nil)
  end

  ## private {:ok, id, module_name} / {:error, e}
  defp verify_unique({:error, e}), do: {:error, e}

  defp verify_unique({:ok, id, module_name}) do
    case exist?(id, module_name) do
      false -> {:ok, id, module_name}
      true -> {:error, "name already in use"}
    end
  end

  defp store_state({:error, e}), do: {:error, e}

  defp store_state({:ok, id, module_name}, state, %Event{} = event) do
    case Data.save_state_with_log(module_name, id, state, event) do
      :ok -> {:ok, id, module_name}
      _ -> {:error, "could not save state"}
    end
  end

  defp start_new({:error, e}), do: {:error, e}

  defp start_new({:ok, id, module_name}, state) do
    process_name = Data.genserver_id(module_name, id)

    case GenServer.start(select_module(module_name), state, name: process_name) do
      {:ok, _pid} ->
        {:ok, id, module_name}

      {:error, e} ->
        {:error, e}
    end
  end

  defp rerun_from_log({:error, e}), do: {:error, e}

  defp rerun_from_log({:ok, id, module_name}) do
    {:ok, id, module_name}
    |> wipe_state()
    |> run_log()
    |> conclude_rerun()
    |> select_rerun_return()
  end

  defp wipe_state({:error, e}), do: {:error, e}

  defp wipe_state({:ok, id, module_name}) do
    case Data.wipe_state([id], module_name) do
      :ok -> {:ok, id, module_name}
      _ -> {:error, "Failed to wipe current state of #{module_name} #{id}"}
    end
  end

  defp run_log({:error, e}), do: {:error, e}

  defp run_log({:ok, id, module_name}) do
    module = select_module(module_name)
    stop(id, module_name)

    case Data.read_log_by_id(id, module_name) do
      {:error, :not_found} ->
        {:error, "Log of #{module_name} #{id} not found"}

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
  defp return_result({:ok, _id, _module_name}), do: :ok

  defp select_module(module_name) when is_bitstring(module_name) do
    case String.downcase(module_name) do
      "player" -> Player
      "deck" -> Deck
      "game" -> Game
      "match" -> Match
      "result" -> Result
      "tag" -> Tag
      _ -> {:error, "#{module_name} is not a valid name selecting module"}
    end
  end

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

  defp select_module_struct(module_name) when is_bitstring(module_name) do
    case String.downcase(module_name) do
      "player" -> %Player{}
      "deck" -> %Deck{}
      "game" -> %Game{}
      "match" -> %Match{}
      "result" -> %Result{}
      "tag" -> %Tag{}
      _ -> {:error, "#{module_name} is not a valid module selecting struct"}
    end
  end

  defp validate_module({:error, e}), do: {:error, e}

  defp validate_module({:ok, id, module_name}) when is_bitstring(module_name) do
    case module_name do
      "Player" -> {:ok, id, module_name}
      "Deck" -> {:ok, id, module_name}
      "Game" -> {:ok, id, module_name}
      "Match" -> {:ok, id, module_name}
      "Result" -> {:ok, id, module_name}
      "Tag" -> {:ok, id, module_name}
      _ -> {:error, "#{module_name} is not a valid module name"}
    end
  end

  defp module_has_state({:error, e}), do: {:error, e}

  defp module_has_state({:ok, id, module_name})
       when is_bitstring(id) and is_bitstring(module_name) do
    Data.state_exists?(module_name, id)
  end

  defp verified_id({:error, e}), do: {:error, e}

  defp verified_id({:ok, id, module_name}) when is_bitstring(id) and is_bitstring(module_name) do
    case module_has_state({:ok, id, module_name}) do
      true -> {:ok, id, module_name}
      false -> {:error, "#{module_name} #{id} not found"}
    end
  end

  defp recall({:error, e}), do: {:error, e}

  defp recall({:ok, id, module_name}) do
    GenServer.call(Data.genserver_id(module_name, id), %{
      keys: [:read, select_module_atom(module_name)]
    })
  end

  defp ready_process({:error, e}), do: {:error, e}

  defp ready_process({:ok, id, module_name}) do
    # Is running?
    case {GenServer.whereis(Data.genserver_id(module_name, id)),
          Data.state_exists?(module_name, id)} do
      {nil, true} ->
        start_process({:ok, id, module_name})

      {nil, false} ->
        {:error, :no_such_id}

      _ ->
        {:ok, id, module_name}
    end
  end

  defp start_process({:ok, id, module_name}) do
    # Get state
    current_state =
      Map.merge(select_module_struct(module_name), Data.recall_state(module_name, id))

    case GenServer.start(select_module(module_name), current_state,
           name: Data.genserver_id(module_name, id)
         ) do
      {:ok, _pid} -> {:ok, id, module_name}
      {:error, reason} -> {:error, reason}
      x -> {:error, inspect(x)}
    end
  end

  defp alter({:error, e}, _keys, _data, _event), do: {:error, e}

  defp alter({:ok, id, module_name}, keys, data, event) do
    # Call update
    GenServer.call(Data.genserver_id(module_name, id), %{keys: keys, data: data, event: event})
  end
end

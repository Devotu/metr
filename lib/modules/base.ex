defmodule Metr.Modules.Stately do
  alias Metr.Data
  alias Metr.Event
  alias Metr.Util

  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result

  def exist?(id, module_name) do
    {:ok, id, module_name}
    |> validate_module()
    |> module_has_state()
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

  def update(id, module_name, tags, data, event) do
    {:ok, id, module_name}
    |> validate_module()
    |> verified_id()
    |> ready_process()
    |> alter(tags, data, event)
  end

  def out_to_event(msg, module_name, tags) when is_bitstring(module_name) do
    Event.new([select_module_atom(module_name)] ++ tags, %{out: msg})
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
    case Data.wipe_state(module_name, [id]) do
      :ok -> {:ok, id, module_name}
      _ -> {:error, "Failed to wipe current state of #{module_name} #{id}"}
    end
  end

  defp run_log({:error, e}), do: {:error, e}
  defp run_log({:ok, id, module_name}) do
    module = select_module(module_name)
    stop(id, module_name)

    case Data.read_log_by_id(module_name, id) do
      {:error, :not_found} ->
        {:error, "#{module_name} #{id} not found"}
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
    |> Enum.filter(fn e -> Enum.member?(e.tags, :error) end)
  end

  defp select_rerun_return({:error, e}), do: {:error, e}
  defp select_rerun_return([]), do: :ok
  defp select_rerun_return(error_events) when is_list(error_events), do: {:error, Kernel.inspect(error_events)}

  defp return_result({:error, e}), do: {:error, e}
  defp return_result({:ok, _id, _module_name}), do: :ok

  defp select_module(module_name) when is_bitstring(module_name) do
    case module_name do
      "Player" -> Player
      "Deck" -> Deck
      "Game" -> Game
      "Match" -> Match
      "Result" -> Result
      _ -> {:error, "#{module_name} is not a valid module selecting module"}
    end
  end

  defp select_module_atom(module_name) when is_bitstring(module_name) do
    case module_name do
      "Player" -> :player
      "Deck" -> :deck
      "Game" -> :game
      "Match" -> :match
      "Result" -> :result
      _ -> {:error, "#{module_name} is not a valid module name selecting atom"}
    end
  end

  defp select_module_struct(module_name) when is_bitstring(module_name) do
    case module_name do
      "Player" -> %Player{}
      "Deck" -> %Deck{}
      "Game" -> %Game{}
      "Match" -> %Match{}
      "Result" -> %Result{}
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
      _ -> {:error, "#{module_name} is not a valid module name"}
    end
  end

  defp module_has_state({:error, e}), do: {:error, e}

  defp module_has_state({:ok, id, module_name}) when is_bitstring(id) and is_bitstring(module_name) do
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
    GenServer.call(Data.genserver_id(module_name, id), %{tags: [:read, select_module_atom(module_name)]})
  end

  defp ready_process({:error, e}), do: {:error, e}

  defp ready_process({:ok, id, module_name}) do
    # Is running?
    case {GenServer.whereis(Data.genserver_id(module_name, id)), Data.state_exists?(module_name, id)} do
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
    current_state = Map.merge(select_module_struct(module_name), Data.recall_state(module_name, id))
    case GenServer.start(select_module(module_name), current_state, name: Data.genserver_id(module_name, id)) do
      {:ok, _pid} -> {:ok, id, module_name}
      {:error, reason} -> {:error, reason}
      x -> {:error, inspect(x)}
    end
  end

  defp alter({:error, e}, _tags, _data, _event), do: {:error, e}

  defp alter({:ok, id, module_name}, tags, data, event) do
    # Call update
    GenServer.call(Data.genserver_id(module_name, id), %{tags: tags, data: data, event: event})
  end
end

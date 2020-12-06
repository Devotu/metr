defmodule Metr.Modules.Base do
  alias Metr.Data
  alias Metr.Event

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
      {:ok, _id, _module} -> {:ok}
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

  defp select_module_atom(module_name) when is_bitstring(module_name) do
    case module_name do
      "Player" -> :player
      "Deck" -> :deck
      "Game" -> :game
      "Match" -> :match
      "Result" -> :result
      _ -> {:error, "#{module_name} is not a valid module"}
    end
  end

  defp select_module(module_name) when is_bitstring(module_name) do
    case module_name do
      "Player" -> %Player{}
      "Deck" -> %Deck{}
      "Game" -> %Game{}
      "Match" -> %Match{}
      "Result" -> %Result{}
      _ -> {:error, "#{module_name} is not a valid module"}
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

  defp module_has_state({:ok, id, module}) when is_bitstring(id) and is_bitstring(module) do
    Data.state_exists?(module, id)
  end

  defp verified_id({:error, e}), do: {:error, e}

  defp verified_id({:ok, id, module}) when is_bitstring(id) and is_bitstring(module) do
    case module_has_state({:ok, id, module}) do
      true -> {:ok, id, module}
      false -> {:error, "#{module} #{id} not found"}
    end
  end

  defp recall({:error, e}), do: {:error, e}

  defp recall({:ok, id, module}) do
    GenServer.call(Data.genserver_id(module, id), %{tags: [:read, select_module_atom(module)]})
  end

  defp ready_process({:error, e}), do: {:error, e}

  defp ready_process({:ok, id, module}) do
    # Is running?
    case {GenServer.whereis(Data.genserver_id(module, id)), Data.state_exists?(module, id)} do
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
    current_state = Map.merge(select_module(module), Data.recall_state(module, id))

    case GenServer.start(Metr.Modules.Player, current_state, name: Data.genserver_id(module, id)) do
      {:ok, _pid} -> {:ok, id}
      {:error, reason} -> {:error, reason}
      x -> {:error, inspect(x)}
    end
  end

  defp alter({:error, e}, _tags, _data, _event), do: {:error, e}

  defp alter({:ok, id, module}, tags, data, event) do
    # Call update
    GenServer.call(Data.genserver_id(module, id), %{tags: tags, data: data, event: event})
  end
end

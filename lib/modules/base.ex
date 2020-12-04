defmodule Metr.Modules.Base do

  alias Metr.Data
  alias Metr.Event

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
    result = {:ok, id, module_name}
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




  defp validate_module({:error, e}), do: {:error, e}
  defp validate_module({:ok, id, module}) when is_bitstring(module) do
    case module do
      "Player" -> {:ok, id, module}
      "Deck" -> {:ok, id, module}
      "Game" -> {:ok, id, module}
      "Match" -> {:ok, id, module}
      "Result" -> {:ok, id, module}
      _ -> {:error, "#{module} is not a valid module name"}
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
    GenServer.call(Data.genserver_id(module, id), %{tags: [:read, :player]})
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
    current_state = Map.merge(%Player{}, Data.recall_state(module, id))

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

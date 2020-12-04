defmodule Metr.Modules.Base do

  alias Metr.Data

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
    case module_name do
      "Player" -> {:ok}
      "Deck" -> {:ok}
      "Game" -> {:ok}
      "Match" -> {:ok}
      "Result" -> {:ok}
      _ -> {:error, "#{module_name} is not a valid module name"}
    end
  end

  def module_has_state({:error, e}), do: {:error, e}
  def module_has_state({:ok}, id, module_name) when is_bitstring(id) and is_bitstring(module_name) do
    Data.state_exists?(module_name, id)
  end
  def module_has_state(id, module_name) when is_bitstring(id) and is_bitstring(module_name) do
    case validate_module_name(module_name) do
      {:ok} -> Data.state_exists?(module_name, id)
      e -> e
    end
  end

  def verified_id(id, module_name) when is_bitstring(id) and is_bitstring(module_name) do
    case module_has_state(id, module_name) do
      true -> {:ok, id}
      e -> e
    end
  end

end

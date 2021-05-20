defmodule Metr.Data do
  @moduledoc """
  A thin layer on top of Trail in order to provide functions that cannot be eliminated
  as the current live data contains dependencies on this logic.
  The core of the problem is that each state is saved with id in the format [module]_[id]
  but only refered to as [id] within saved logs.
  The origin is the ide to have each module as its own namespace in storage (which is good)
  but it should have been handled the other way around.
  Id should always include its namespace throughout the application and data.

  Hard lesson to be learned!
  """

  @id_input "input"

  def log_external_input(event) do
    Trail.store(@id_input, %{}, event)
  end

  def save_state_with_log(module, id, state, event) when is_atom(module) and is_bitstring(id) do
    module_specific_id(module, id)
    |> Trail.store(state, event)
  end

  @spec read_log_by_id(bitstring, atom) :: list | {:error, :not_found}
  def read_log_by_id(id, module) when is_atom(module) and is_bitstring(id) do
    module_specific_id(module, id)
    |> Trail.trace()
  end

  def read_input_log_tail(limit \\ 100) do
    @id_input
    |> Trail.trace()
    |> Enum.reverse()
    |> Enum.take(limit)
    |> Enum.reverse()
  end

  def recall_state(module, id) when is_atom(module) and is_bitstring(id) do
    module_specific_id(module, id)
    |> Trail.recall()
  end

  def state_exists?(module, id) when is_atom(module) and is_bitstring(id) do
    module_specific_id(module, id)
    |> Trail.has_state?()
  end

  def wipe_state(ids, module) when is_atom(module) and is_list(ids) do
    Enum.each(ids, fn id -> wipe_state(id, module) end)
  end

  def wipe_state(id, module) when is_atom(module) and is_bitstring(id) do
    module_specific_id(module, id)
    |> Trail.clear()
  end

  def list_ids(module) when is_atom(module) do
    module
    |> to_module_name()
    |> Trail.list_contains()
    |> Enum.map(fn module_id -> extract_id(module_id, module) end)
  end

  ## Hard to get rid of id functions
  @spec module_specific_id(atom, bitstring()) :: <<_::8, _::_*8>>
  def module_specific_id(module, id) when is_atom(module) and is_bitstring(id) do
    "#{to_module_name(module)}_#{id}"
  end

  defp extract_id(name, module) do
    name
    |> String.replace_prefix(to_module_name(module), "")
    |> String.replace_prefix("_", "")
    |> String.replace_suffix(".state", "")
  end

  def genserver_id(module, id) when is_atom(module) and is_bitstring(id) do
    {:global, module_specific_id(module, id)}
  end

  defp to_module_name(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.trim_leading(":")
    |> String.capitalize()
  end
end

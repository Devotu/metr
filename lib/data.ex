defmodule Metr.Data do
  defp data_dir(), do: File.cwd!() <> "/data"

  defp event_dir(), do: data_dir() <> "/event"
  defp event_path(module, id) when is_atom(module) and is_bitstring(id) do
    event_dir() <> "/#{module_specific_id(module, id)}.log"
  end

  @id_input "input"

  def log_external_input(event) do
    Trail.store(@id_input, %{}, event)
  end

  def save_state_with_log(module, id, state, event) when is_atom(module) and is_bitstring(id)  do
    module_specific_id(module, id)
    |> Trail.store(state, event)
  end

  @spec read_log_by_id(bitstring, atom) :: list | {:error, :not_found}
  def read_log_by_id(id, module) when is_atom(module) and is_bitstring(id)  do
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

  def wipe_state(id, module) when is_atom(module) and is_bitstring(id)  do
    module_specific_id(module, id)
    |> Trail.clear()
  end

  ####  All functions above are migrated to Trail ####


  defp state_dir(), do: data_dir() <> "/state"
  defp state_path(module, id) when is_atom(module) and is_bitstring(id) do
    state_dir() <> "/#{module_specific_id(module, id)}.state"
  end








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

  def genserver_id(module, id) when is_atom(module) and is_bitstring(id)  do
    {:global, module_specific_id(module, id)}
  end

  def list_ids(module) when is_atom(module) do
    File.ls!(state_dir())
    |> Enum.map(fn fp -> String.replace(fp, state_dir(), "") end)
    |> Enum.filter(fn fp -> String.starts_with?(fp, to_module_name(module)) end)
    |> Enum.map(fn fp -> extract_id(fp, module) end)
  end

  defp to_module_name(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.trim_leading(":")
    |> String.capitalize()
  end
end

defmodule Metr.Data do
  @delimiter "*___*_*_*"

  defp data_dir(), do: File.cwd!() <> "/data"

  defp event_dir(), do: data_dir() <> "/event"
  defp event_path(module, id) when is_atom(module) and is_bitstring(id) do
    event_dir() <> "/#{entity_id(module, id)}.log"
  end

  @id_input "input"

  def log_external_input(event) do
    Trail.store(@id_input, %{}, event)
  end

  def save_state_with_log(module, id, state, event) when is_atom(module) and is_bitstring(id)  do
    entity_id(module, id)
    |> Trail.store(state, event)
  end

  @spec read_log_by_id(bitstring, atom) :: list | {:error, :not_found}
  def read_log_by_id(id, module) when is_atom(module) and is_bitstring(id)  do
    entity_id(module, id)
    |> Trail.trace()
  end

  def read_input_log_tail(limit \\ 100) do
    @id_input
    |> Trail.trace()
    |> Enum.reverse()
    |> Enum.take(limit)
    |> Enum.reverse()
  end

  ####  All functions above are migrated to Trail ####

  def wipe_log(module, ids)  when is_atom(module) and is_list(ids) do
    Enum.each(ids, fn id -> wipe_log(module, id) end)
  end

  def wipe_log(module, id) when is_atom(module) and is_bitstring(id)  do
    path = event_path(module, id)
    File.rm(path)
  end

  defp state_dir(), do: data_dir() <> "/state"
  defp state_path(module, id) when is_atom(module) and is_bitstring(id) do
    state_dir() <> "/#{entity_id(module, id)}.state"
  end

  def recall_state(module, id) when is_atom(module) and is_bitstring(id)  do
    state_path(module, id)
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  def state_exists?(module, id) when is_atom(module) and is_bitstring(id)  do
    File.exists?(state_path(module, id))
  end

  def wipe_state(ids, module) when is_list(ids) do
    Enum.each(ids, fn id -> wipe_state(id, module) end)
  end

  def wipe_state(id, module) do
    path = state_path(module, id)
    File.rm(path)
  end

  @spec entity_id(atom, bitstring()) :: <<_::8, _::_*8>>
  def entity_id(module, id) when is_atom(module) and is_bitstring(id) do
    "#{to_module_name(module)}_#{id}"
  end

  defp extract_id(name, module) do
    name
    |> String.replace_prefix(to_module_name(module), "")
    |> String.replace_prefix("_", "")
    |> String.replace_suffix(".state", "")
  end

  def genserver_id(module, id) when is_atom(module) and is_bitstring(id)  do
    {:global, entity_id(module, id)}
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

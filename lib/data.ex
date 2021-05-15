defmodule Metr.Data do
  @delimiter "*___*_*_*"

  defp data_dir(), do: File.cwd!() <> "/data"

  defp event_dir(), do: data_dir() <> "/event"
  defp event_path_external_inputs(), do: event_dir() <> "/input.log"
  defp event_path(module, id) when is_atom(module) and is_bitstring(id) do
    event_dir() <> "/#{entity_id(module, id)}.log"
  end

  def log_external_input(event) do
    bin = :erlang.term_to_binary(event)
    del = bin <> @delimiter
    File.write!(event_path_external_inputs(), del, [:append])
  end

  def save_state_with_log(module, id, state, event) when is_atom(module) and is_bitstring(id)  do
    save_state(module, id, state)
    log_by_id(module, id, event)
  end

  def log_by_id(module, id, event) when is_atom(module) and is_bitstring(id) do
    path = event_path(module, id)
    bin = :erlang.term_to_binary(event)
    del = bin <> @delimiter
    File.write!(path, del, [:append])
  end

  def read_log_by_id(id, module) when is_atom(module) and is_bitstring(id)  do
    event_path(module, id)
    |> read_binary_from_path
    |> parse_delimited_binary
  end

  def wipe_log(module, ids)  when is_atom(module) and is_list(ids) do
    Enum.each(ids, fn id -> wipe_log(module, id) end)
  end

  def wipe_log(module, id) when is_atom(module) and is_bitstring(id)  do
    path = event_path(module, id)
    File.rm(path)
  end

  def read_input_log_tail(limit \\ 100) do
    event_path_external_inputs()
    |> read_binary_from_path
    |> parse_delimited_binary
    |> Enum.reverse()
    |> Enum.take(limit)
    |> Enum.reverse()
  end

  defp read_binary_from_path(path) do
    case File.read(path) do
      {:ok, binary} ->
        binary

      {:error, cause} ->
        {:error, cause}
    end
  end

  defp parse_delimited_binary({:error, :enoent}) do
    {:error, :not_found}
  end

  defp parse_delimited_binary(binary) do
    binary
    |> String.slice(0..-String.length(@delimiter))
    |> String.split(@delimiter)
    |> Enum.map(fn b -> :erlang.binary_to_term(b) end)
  end

  defp state_dir(), do: data_dir() <> "/state"
  defp state_path(module, id) when is_atom(module) and is_bitstring(id) do
    state_dir() <> "/#{entity_id(module, id)}.state"
  end

  defp save_state(module, id, state) when is_atom(module) and is_bitstring(id) do
    path = state_path(module, id)
    bin = :erlang.term_to_binary(state)
    File.write!(path, bin)
  end

  def recall_state(module, id) when is_atom(module) and is_bitstring(id)  do
    state_path(module, id)
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  def state_exists?(module, id) when is_atom(module) and is_bitstring(id)  do
    IO.inspect(state_path(module, id), label: "data - state_path")
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

  defp module_to_name(module) do
    module
    |> Kernel.inspect()
    |> String.split(".")
    |> List.last()
    |> String.replace("\"", "")
  end

  defp extract_id(name, module) do
    name
    |> String.replace_prefix(module_to_name(module), "")
    |> String.replace_prefix("_", "")
    |> String.replace_suffix(".state", "")
  end

  def genserver_id(module, id) when is_atom(module) and is_bitstring(id)  do
    {:global, entity_id(module, id)}
  end

  def list_ids(module) do
    File.ls!(state_dir())
    |> Enum.map(fn fp -> String.replace(fp, state_dir(), "") end)
    |> Enum.filter(fn fp -> String.starts_with?(fp, module_to_name(module)) end)
    |> Enum.map(fn fp -> extract_id(fp, module) end)
  end

  def wipe_test(module, ids) when is_list(ids) when is_atom(module) and is_list(ids)  do
    Enum.each(ids, fn id -> wipe_test(module, id) end)
  end

  def wipe_test(module, id) when is_atom(module) and is_bitstring(id)  do
    wipe_state(id, module)
    wipe_log(module, id)
  end

  defp to_module_name(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.trim_leading(":")
    |> String.capitalize()
  end
end

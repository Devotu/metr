defmodule Metr.Data do
  @delimiter "*___*_*_*"

  defp data_dir(), do: File.cwd!() <> "/data"

  defp event_dir(), do: data_dir() <> "/event"
  defp event_path_external_inputs(), do: event_dir() <> "/input.log"
  defp event_path(module_name, id), do: event_dir() <> "/#{entity_id(module_name, id)}.log"

  def log_external_input(event) do
    bin = :erlang.term_to_binary(event)
    del = bin <> @delimiter
    File.write!(event_path_external_inputs(), del, [:append])
  end

  def save_state_with_log(module_name, id, state, event) do
    save_state(module_name, id, state)
    log_by_id(module_name, id, event)
  end

  def log_by_id(module_name, id, event) do
    path = event_path(module_name, id)
    bin = :erlang.term_to_binary(event)
    del = bin <> @delimiter
    File.write!(path, del, [:append])
  end

  def read_log_by_id(id, module_name) do
    event_path(module_name, id)
    |> read_binary_from_path
    |> parse_delimited_binary
  end

  def wipe_log(module_name, ids) when is_list(ids) do
    Enum.each(ids, fn id -> wipe_log(module_name, id) end)
  end

  def wipe_log(module_name, id) do
    path = event_path(module_name, id)
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

      {:error, reason} ->
        {:error, reason}
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
  defp state_path(module_name, id), do: state_dir() <> "/#{entity_id(module_name, id)}.state"

  def save_state(module_name, id, state) do
    path = state_path(module_name, id)
    bin = :erlang.term_to_binary(state)
    File.write!(path, bin)
  end

  def recall_state(module_name, id) do
    state_path(module_name, id)
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  def state_exists?(module_name, id) do
    File.exists?(state_path(module_name, id))
  end

  def wipe_state(ids, module_name) when is_list(ids) do
    Enum.each(ids, fn id -> wipe_state(id, module_name) end)
  end

  def wipe_state(id, module_name) do
    IO.inspect module_name, label: "Data wipe - module"
    IO.inspect id, label: "Data wipe - id"
    path = state_path(module_name, id)
    File.rm(path)
  end

  @spec entity_id(binary, any) :: <<_::8, _::_*8>>
  def entity_id(module_name, id) do
    "#{module_to_name(module_name)}_#{id}"
  end

  defp module_to_name(module_name) do
    module_name
    |> Kernel.inspect()
    |> String.split(".")
    |> List.last()
    |> String.replace("\"", "")
  end

  defp extract_id(name, module_name) do
    name
    |> String.replace_prefix(module_to_name(module_name), "")
    |> String.replace_prefix("_", "")
    |> String.replace_suffix(".state", "")
  end

  def genserver_id(module_name, id) do
    {:global, entity_id(module_name, id)}
  end

  def list_ids(module_name) do
    File.ls!(state_dir())
    |> Enum.map(fn fp -> String.replace(fp, state_dir(), "") end)
    |> Enum.filter(fn fp -> String.starts_with?(fp, module_to_name(module_name)) end)
    |> Enum.map(fn fp -> extract_id(fp, module_name) end)
  end

  def wipe_test(module_name, ids) when is_list(ids) do
    Enum.each(ids, fn id -> wipe_test(module_name, id) end)
  end

  def wipe_test(module_name, id) do
    wipe_state(id, module_name)
    wipe_log(module_name, id)
  end
end

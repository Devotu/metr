defmodule Metr.Data do
  @delimiter "**"

  defp data_dir(), do: File.cwd! <> "/data"

  defp event_dir(), do: data_dir() <> "/event"
  defp event_path(), do: event_dir() <> "/all.log"


  def log_event(event) do
    bin = :erlang.term_to_binary(event)
    del = bin <> @delimiter
    File.write!(event_path(), del, [:append])
  end


  def read_log_tail(number \\ 100) do
    event_path()
    |> read_binary_from_path
    |> parse_delimited_binary
    |> Enum.reverse()
    |> Enum.take(number)
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
    |> String.slice( 0..-String.length(@delimiter) )
    |> String.split( @delimiter )
    |> Enum.map( fn b -> :erlang.binary_to_term(b) end )
  end


  defp state_dir(), do: data_dir() <> "/state"
  defp state_path(module_full_name, id), do: state_dir() <> "/#{state_id(module_full_name, id)}.state"


  def save_state(module_full_name, id, state) do
    path = state_path(module_full_name, id)
    bin = :erlang.term_to_binary(state)
    File.write!(path, bin)
  end


  def recall_state(module_full_name, id) do
    state_path(module_full_name, id)
    |> File.read!()
    |> :erlang.binary_to_term()
  end


  def state_exists?(module_name, id) do
    File.exists?(state_path(module_name, id))
  end


  def wipe_state(module_full_name, id) do
    path = state_path(module_full_name, id)
    File.rm(path)
  end


  @spec state_id(binary, any) :: <<_::8, _::_*8>>
  def state_id(module_full_name, id) do
    module_name = module_full_name
    |> Kernel.inspect()
    |> String.split(".")
    |> List.last()
    |> String.replace("\"", "")
    "#{module_name}_#{id}"
  end


  def genserver_id(module_full_name, id) do
    {:global, state_id(module_full_name, id)}
  end
end

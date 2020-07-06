defmodule Metr.Data do
  defp data_dir(), do: File.cwd! <> "/data"
  defp state_dir(), do: data_dir() <> "/state"
  defp state_path(module_full_name, id), do: state_dir() <> "/#{state_id(module_full_name, id)}.state"


  def save_state(module_full_name, id, state) do
    path = state_path(module_full_name, id)
    bin = :erlang.term_to_binary(state)
    File.write!(path, bin)
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

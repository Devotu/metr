defmodule Metr.Data do
  def data_path(), do: File.cwd! <> "/data"
  def event_path(), do: data_path() <> "/event"
  def state_path(), do: data_path() <> "/state"


  def save_state(module_name, id, state) do
    path = state_path() <> "/" <> state_id(module_name, id) <> ".state"
    bin = :erlang.term_to_binary(state)
    File.write!(path, bin)
  end


  @spec state_id(binary, any) :: <<_::8, _::_*8>>
  def state_id(module_full_name, id) do
    module_name = module_full_name
    |> Kernel.inspect()
    |> String.split(".")
    |> List.last()
    "#{module_name}_#{id}"
  end


  def genserver_id(module_name, id) do
    {:global, state_id(module_name, id)}
  end
end

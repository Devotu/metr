defmodule Metr.History do
  alias Metr.Modules.Stately
  alias Metr.Data

  def of_entity(id, module) when is_atom(module) and is_bitstring(id) do
    module_name = Stately.select_module_name(module)
    log = Data.read_log_by_id(id, module_name)
    case log do
      nil -> {:error, "Log of #{Kernel.inspect(module)} #{id} not found"}
      log ->
        Stately.stop(id, module_name)
        Data.wipe_state(id, module_name)
        Enum.reduce(log, [], fn e, acc -> acc ++ [step(id, module, e)] end)
    end
  end

  defp step(id, module, event) do
    Stately.apply_event(id, module, event)
    state = Stately.read(id, module)
    data = Data.recall_state(Stately.select_module_name(module), id)
    %{event: event, state: state, data: data}
  end
end

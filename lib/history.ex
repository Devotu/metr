defmodule Metr.History do
  alias Metr.Modules.Stately
  alias Metr.Data

  def of_entity(module, id) when is_atom(module) and is_bitstring(id) do
    Data.read_log_by_id(Stately.select_module_name(module), id)
    |> Enum.reduce([], fn e, acc -> acc ++ [step(id, module, e)] end)
  end

  defp step(id, module, event) do
    Stately.apply_event(id, module, event)
    state = Stately.read(id, module)
    data = Data.recall_state(Stately.select_module_name(module), id)
    %{event: event, state: state, data: data}
  end
end

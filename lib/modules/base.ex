defmodule Metr.Modules.Base do

  alias Metr.Data

  def verify_id(id, module) when is_bitstring(id) and is_atom(module) do
    case Data.state_exists?(module_data_name(module), id) do
      true -> {:ok, id}
      false -> {:error, "deck not found"}
    end
  end

  def module_data_name(module) when is_atom(module) do
    case module do
      :player -> "player"
      :deck -> "deck"
      :game -> "game"
      :match -> "match"
      :result -> "result"
    end
  end
end

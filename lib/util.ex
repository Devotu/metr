defmodule Metr.Util do
  def has_member?(list_x, list_y) when is_list(list_x) and is_list(list_y) do
    0 <
      list_x
      |> Enum.filter(fn x -> Enum.member?(list_y, x) end)
      |> Enum.count()
  end

  def find_first_common_member(list_x, list_y) when is_list(list_x) and is_list(list_y) do
    list_x
    |> Enum.filter(fn x -> Enum.member?(list_y, x) end)
    |> List.first()
  end

  def uniq({:error, e}), do: {:error, e}
  def uniq(list) do
    uniq(list, MapSet.new())
  end

  defp uniq([x | rest], found) do
    if MapSet.member?(found, x) do
      uniq(rest, found)
    else
      [x | uniq(rest, MapSet.put(found, x))]
    end
  end

  defp uniq([], _) do
    []
  end
end

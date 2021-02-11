defmodule Metr.Util do
  alias Metr.Time

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

  def stamp_ts_map(current_map, item_name) do
    case Map.has_key?(current_map, item_name) do
      true ->
        Map.put(current_map, item_name, current_map[item_name] ++ [Time.timestamp()])
      false ->
        Map.put(current_map, item_name, [Time.timestamp()])
    end
  end
end

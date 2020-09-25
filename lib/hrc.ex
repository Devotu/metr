defmodule Metr.HRC do
  defstruct action: nil, subject: nil, details: %{}, parts: []

  alias Metr.HRC

  def parse(input) do
    input
    |> String.split()
    |> (fn bits -> {bits, %HRC{}} end).()
    |> parse_action()
    |> parse_subject()
    |> parse_id()
    |> parse_details()
  end


  defp parse_action({[action|remaining], %{} = acc}) do
    {remaining, Map.put(acc, :action, String.to_atom(action))}
  end


  defp parse_subject({[subject|remaining], %{} = acc}) do
    {remaining, Map.put(acc, :subject, String.to_atom(subject))}
  end


  defp parse_id({["all"|_remaining], %{} = acc}) do
    {[], acc}
  end

  defp parse_id({["with"|_remaining] = data_with_no_id, %{} = acc}) do
    {data_with_no_id, acc}
  end

  defp parse_id({[id|remaining], %{} = acc}) do
    {remaining, Map.put(acc, :details, %{id: id})}
  end


  defp parse_details({[], %{} = acc}) do
    acc
  end

  defp parse_details({["with"|bits], %{} = acc}) do
    bits
    |> Enum.chunk_by(fn b -> "with" == b end)
    |> Enum.reduce(acc, fn part, acc -> parse_pairs({part, acc}) end)
  end


  defp parse_pairs({[], %{} = acc}) do
    acc
  end

  defp parse_pairs({["with"|bits], %{} = acc}) do
    parse_pairs({bits, acc})
  end

  defp parse_pairs({["part"|bits], %{} = acc}) do
    [id|kvs] = bits
    part = %{part: parse_value(id), details: %{}}
    part_map = kvs
    |> Enum.chunk_by(fn b -> "and" == b end)
    |> Enum.reduce(part, fn kv, acc -> merge_kv(kv, acc) end)

    Map.put(acc, :parts, acc.parts ++ [part_map])
  end

  defp parse_pairs({bits, %{} = acc}) when is_list(bits) do
    bits
    |> Enum.chunk_by(fn b -> "and" == b end)
    |> Enum.reduce(acc, fn kv, acc -> merge_kv(kv, acc) end)
  end


  defp merge_kv(["and"], acc) do
    acc
  end

  defp merge_kv([k, v], %{details: details} = acc) do
    case {k, parse_value(v)} do
      {"color", _} ->
        updated_colors = Map.fetch(details, :colors)
          |> no_ok()
          |> merge_colors(String.to_atom(v))
        Map.put(acc, :details, Map.put(details, :colors, updated_colors)) #TODO validate color
      {_, pv} ->
        Map.put(acc, :details, Map.put(details, String.to_atom(k), pv))
    end
  end


  defp merge_colors(:error, new) do
    [new]
  end

  defp merge_colors(current, new) when is_list(current) do
    current ++ [new]
  end


  defp no_ok({:ok, term}), do: term
  defp no_ok(term), do: term


  defp parse_value(v) do
    v
    |> parse_text_scale()
    |> parse_number()
  end


  defp parse_text_scale(v) do
    case v do
      "bad" ->
        -2
      "negative" ->
        -1
      "neutral" ->
        0
      "positive" ->
        1
      "good" ->
        2
      _ ->
        v
    end
  end


  defp parse_number(v) when is_number(v), do: v
  defp parse_number(v) do
    case Integer.parse(v) do
      {int, _} ->
        int
      _ ->
        v
    end
  end
end

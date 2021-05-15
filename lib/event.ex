defmodule Metr.Event do
  defstruct id: "", keys: [], data: %{}, time: 0

  alias Metr.Id
  alias Metr.Event
  alias Metr.HRC
  alias Metr.Time

  def new(%HRC{} = hrc) do
    {keys, data, _hrc} =
      {[], [], hrc}
      |> add_action()
      |> add_subject()
      |> add_details()
      |> add_parts()

    merged_data = merge_data(data)
    merged_data = Map.put(merged_data, :rank, false)
    new(keys, merged_data)
  end

  def new(keys, data \\ %{})
  def new(keys, data) when is_list(keys) do
    %Event{id: Id.guid(), keys: keys, data: data, time: Time.timestamp()}
  end
  def new(data, keys) when is_list(keys) and is_map(data) do
    %Event{id: Id.guid(), keys: keys, data: data, time: Time.timestamp()}
  end
  def new(data, keys) when is_list(keys) and is_struct(data) do
    %Event{id: Id.guid(), keys: keys, data: data, time: Time.timestamp()}
  end


  def only_errors(events) when is_list(events) do
    Enum.filter(events, fn e ->
      Enum.any?(e.keys, fn t ->
        t == :error
      end)
    end)
  end

  def add_repp(event, repp) do
    event
    |> Map.put(:keys, event.keys ++ [repp])
  end

  defp add_action({keys, data, %HRC{action: nil} = hrc}), do: {keys, data, hrc}

  defp add_action({keys, data, hrc}) do
    {keys ++ [hrc.action], data, hrc}
  end

  defp add_subject({keys, data, %HRC{subject: nil} = hrc}), do: {keys, data, hrc}

  defp add_subject({keys, data, hrc}) do
    {keys ++ [hrc.subject], data, hrc}
  end

  defp add_details({keys, data, %HRC{details: nil} = hrc}), do: {keys, data, hrc}

  defp add_details({keys, data, hrc}) do
    {keys, data ++ [hrc.details], hrc}
  end

  defp add_parts({keys, data, %HRC{parts: nil} = hrc}), do: {keys, data, hrc}

  defp add_parts({keys, data, hrc}) do
    {keys, data ++ [hrc.parts], hrc}
  end

  defp merge_data([details, parts]) when is_map(details) do
    details
    |> Map.put(:parts, parts)
  end
end

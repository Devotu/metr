defmodule Metr.Event do
  defstruct id: "", tags: [], data: %{}, time: 0

  alias Metr.Id
  alias Metr.Event
  alias Metr.HRC
  alias Metr.Time

  def new(%HRC{} = hrc) do
    {tags, data, _hrc} =
      {[], [], hrc}
      |> add_action()
      |> add_subject()
      |> add_details()
      |> add_parts()

    merged_data = merge_data(data)
    merged_data = Map.put(merged_data, :rank, false)
    new(tags, merged_data)
  end


  def new(tags, data \\ %{}) when is_list(tags) do
    %Event{id: Id.guid(), tags: tags, data: data, time: Time.timestamp()}
  end


  def only_errors(events) when is_list(events) do
    Enum.filter(events, fn e ->
      Enum.any?(e.tags, fn t ->
        t == :error
      end)
    end)
  end


  def add_repp(event, repp) do
    event
    |> Map.put(:tags, event.tags ++ [repp])
  end



  defp add_action({tags, data, %HRC{action: nil} = hrc}), do: {tags, data, hrc}
  defp add_action({tags, data, hrc}) do
    {tags ++ [hrc.action], data, hrc}
  end

  defp add_subject({tags, data, %HRC{subject: nil} = hrc}), do: {tags, data, hrc}
  defp add_subject({tags, data, hrc}) do
    {tags ++ [hrc.subject], data, hrc}
  end

  defp add_details({tags, data, %HRC{details: nil} = hrc}), do: {tags, data, hrc}
  defp add_details({tags, data, hrc}) do
    {tags, data ++ [hrc.details], hrc}
  end

  defp add_parts({tags, data, %HRC{parts: nil} = hrc}), do: {tags, data, hrc}
  defp add_parts({tags, data, hrc}) do
    {tags, data ++ [hrc.parts], hrc}
  end


  defp merge_data([details, parts]) when is_map(details) do
    details
    |> Map.put(:parts, parts)
  end
end

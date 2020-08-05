defmodule Metr.Event do
  defstruct id: "", tags: [], data: %{}

  alias Metr.Id
  alias Metr.Event
  alias Metr.HRC

  def new(%HRC{} = hrc) do
    {tags, data, _hrc} =
      {[], [], hrc}
      |> add_action()
      |> add_subject()
      |> add_details()
      |> add_parts()

    new(tags, merge_data(data))
  end

  def new(tags) when is_list(tags) do
    %Event{id: Id.guid(), tags: tags, data: %{}}
  end

  def new(tags, data) when is_list(tags) do
    %Event{id: Id.guid(), tags: tags, data: data}
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

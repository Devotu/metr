defmodule Metr.Event do
  defstruct id: "", keys: [], data: %{}, time: 0

  alias Metr.Id
  alias Metr.Event
  alias Metr.Time

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
end

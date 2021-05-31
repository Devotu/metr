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

  def error_to_event(cause, repp) when is_pid(repp) do
    Event.new([:error, repp], %{cause: cause})
  end
  def error_to_event(cause, nil) do
    Event.new([:error, nil], %{cause: cause})
  end

  def message_to_event(msg, keys) do
    Event.new(keys, %{out: msg})
  end

  def out_to_event({:ok, out}, entity, repp) when is_atom(entity) and is_pid(repp), do: out_to_event(out, entity, repp)
  def out_to_event(out, entity, repp) when is_atom(entity) and is_pid(repp) do
    Event.new([entity] ++ repp, %{out: out})
  end

  def get_out(%Event{data: %{out: out}}), do: out
  def get_out(%Event{}), do: nil
end

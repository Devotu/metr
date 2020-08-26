defmodule Metr.Log do
  alias Metr.Event
  alias Metr.Data

  def feed(%Event{id: event_id, tags: [:read, :log], data: %{limit: limit}}, _repp) do
    #Return
    [Event.new([:list, :log, event_id], %{entries: Data.read_log_tail(limit)})]
  end

  def feed(_event, _orepp) do
    []
  end
end

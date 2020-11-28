defmodule Metr.Log do
  alias Metr.Event
  alias Metr.Data

  def feed(%Event{id: event_id, tags: [:read, :log], data: %{limit: limit}}, nil) do
    # Return
    [Event.new([:list, :log, event_id], %{entries: Data.read_input_log_tail(limit)})]
  end

  def feed(%Event{id: _event_id, tags: [:read, :log], data: %{limit: limit}}, repp) do
    # Return
    [Event.new([:list, :log, repp], %{out: Data.read_input_log_tail(limit)})]
  end

  def feed(_event, _orepp) do
    []
  end
end

defmodule Metr.Modules.Log do
  alias Metr.Event
  alias Metr.Data

  def feed(event, repp \\ nil)
  def feed(%Event{id: _event_id, keys: [:read, :log], data: %{limit: limit}}, repp) do
    # Return
    [Event.new([:log, repp], %{log: Data.read_input_log_tail(limit)})]
  end

  def feed(_event, _orepp) do
    []
  end
end

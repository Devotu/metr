defmodule Metr.Modules.Log do
  alias Metr.Event
  alias Metr.Data

  # def feed(event, repp \\ nil)
  # def feed(%Event{keys: [:read, :log], data: %{limit: limit}}, repp) do
  #   # Return
  #   [Event.new([:log, :read, repp], %{out: Data.read_input_log_tail(limit)})]
  # end

  def feed(event, _orepp) do
      # IO.inspect event, label: " ---- #{@atom} passed event"
    []
  end
end

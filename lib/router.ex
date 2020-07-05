defmodule Metr.Router do

  alias Metr.Event

  def route(%Event{} = _event) do
    [
      # Module.feed(event),
    ]
    |> Enum.filter(fn e -> Enum.count(e) > 0 end)
    |> Enum.each(fn e -> route(e) end)
  end
end

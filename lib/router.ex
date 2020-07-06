defmodule Metr.Router do

  alias Metr.Event

  def route(%Event{} = event) do
    IO.inspect(event, label: "Routing")

    [
      # Module.feed(event),
    ]
    |> Enum.filter(fn e -> Enum.count(e) > 0 end)
    |> Enum.each(fn e -> route(e) end)
  end
end

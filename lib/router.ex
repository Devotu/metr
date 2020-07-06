defmodule Metr.Router do

  alias Metr.Event
  alias Metr.CLI
  alias Metr.Player

  def route(%Event{} = event) do
    IO.inspect(event, label: "Routing")
    #TODO log

    [
      # Module.feed(event),
      Player.feed(event),
      CLI.feed(event),
    ]
    |> Enum.filter(fn e -> Enum.count(e) > 0 end)
    |> Enum.each(fn e -> route(e) end)
  end
end

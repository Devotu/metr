defmodule Metr.Router do

  alias Metr.Event
  alias Metr.CLI
  alias Metr.Player


  def route(events) when is_list(events) do
    Enum.each(events, &route/1)
  end

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

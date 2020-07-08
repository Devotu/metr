defmodule Metr.Router do

  alias Metr.Event
  alias Metr.CLI
  alias Metr.Data
  alias Metr.Deck
  alias Metr.Player

  def input(events) when is_list(events) do
    Enum.each(events, &input/1)
  end

  def input(%Event{} = event) do
    Data.log_event(event)
    route(event)
  end


  def route(events) when is_list(events) do
    Enum.each(events, &route/1)
  end

  #The actual routing implementation
  def route(%Event{} = event) do
    IO.inspect(event, label: "Router - routing")

    [
      # Module.feed(event),
      Player.feed(event),
      Deck.feed(event),
      CLI.feed(event),
    ]
    |> Enum.filter(fn e -> Enum.count(e) > 0 end)
    |> Enum.each(fn e -> route(e) end)
  end
end

defmodule Metr.Router do

  alias Metr.Event
  alias Metr.CLI
  alias Metr.Data
  alias Metr.Deck
  alias Metr.Game
  alias Metr.Log
  alias Metr.Player

  def input(events) when is_list(events) do
    Enum.each(events, &input/1)
  end

  def input(%Event{} = event) do
    Data.log_event(event)
    route(event)
  end


  defp route(events) when is_list(events) do
    Enum.each(events, &route/1)
  end

  #The actual routing implementation
  defp route(%Event{} = event) do
    [
      # Module.feed(event),
      Player.feed(event),
      Deck.feed(event),
      Game.feed(event),
      Log.feed(event),
      CLI.feed(event),
      Metr.feed(event),
    ]
    |> Enum.filter(fn e -> Enum.count(e) > 0 end)
    |> Enum.each(fn e -> route(e) end)
  end
end

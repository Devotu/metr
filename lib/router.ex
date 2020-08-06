defmodule Metr.Router do

  alias Metr.Event
  alias Metr.CLI
  alias Metr.Data
  alias Metr.Deck
  alias Metr.Game
  alias Metr.Log
  alias Metr.Player

  def input(events, response_pid) when is_list(events) and is_pid(response_pid) do
    Enum.each(events, fn e -> input(e, response_pid) end)
  end

  def input(%Event{} = event, response_pid) when is_pid(response_pid) do
    Data.log_event(event)
    route(event, response_pid)
  end

  def input(events) when is_list(events) do
    Enum.each(events, &input/1)
  end

  def input(%Event{} = event) do
    Data.log_event(event)
    route(event, nil)
  end


  defp route(events) when is_list(events) do
    Enum.each(events, &route/1)
  end

  #The actual routing implementation
  defp route({%Event{} = event, response_pid}), do: route(event, response_pid)
  defp route(%Event{} = event, response_pid \\ nil) do
    [
      # Module.feed(event),
      Player.feed(event, response_pid),
      Deck.feed(event, response_pid),
      Game.feed(event, response_pid),
      Log.feed(event, response_pid),
      CLI.feed(event, response_pid),
      Metr.feed(event, response_pid),
    ]
    |> Enum.filter(fn e -> Enum.count(e) > 0 end)
    |> Enum.each(fn e -> route(e) end)
  end
end

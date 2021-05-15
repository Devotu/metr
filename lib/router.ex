defmodule Metr.Router do
  @moduledoc """
  Core of the application with two closely related tasks
  > Takes input events from the API, stores them, and routes them through all modules
  > Takes events generated from modules and routes the through all modules
  """

  alias Metr.Event
  alias Metr.Data
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Log
  alias Metr.Modules.Match
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Stately
  alias Metr.Modules.Tag

  def input(events, response_pid) when is_list(events) and is_pid(response_pid) do
    Enum.each(events, fn e -> input(e, response_pid) end)
  end

  def input(%Event{} = event, response_pid) when is_pid(response_pid) do
    Data.log_external_input(event)
    route(event, response_pid)
  end

  def input(events) when is_list(events) do
    Enum.each(events, &input/1)
  end

  def input(%Event{} = event) do
    Data.log_external_input(event)
    route(event, nil)
  end

  defp route(events) when is_list(events) do
    Enum.each(events, &route/1)
  end

  # The actual routing implementation
  defp route({%Event{} = event, response_pid}), do: route(event, response_pid)

  defp route(%Event{} = event, response_pid \\ nil) do
    # IO.inspect(event, label: "routing")
    [
      # Module.feed(event),
      Player.feed(event, response_pid),
      Deck.feed(event, response_pid),
      Game.feed(event, response_pid),
      Log.feed(event, response_pid),
      Match.feed(event, response_pid),
      Metr.feed(event, response_pid),
      Result.feed(event, response_pid),
      Stately.feed(event, response_pid),
      Tag.feed(event, response_pid)
    ]
    |> Enum.filter(fn e -> Enum.count(e) > 0 end)
    |> Enum.each(fn e -> route(e) end)
  end
end

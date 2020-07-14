defmodule LogTest do
  use ExUnit.Case

  alias Metr.Log
  alias Metr.CLI
  alias Metr.Event

  test "input read log" do
    assert :ok == CLI.process [{:log, 10}]
  end


  test "read log" do
    number_requested = 5
    sent_event = Event.new([:read, :log], %{number: number_requested})
    [resulting_event] = Log.feed sent_event
    assert [:list, :log, sent_event.id] == resulting_event.tags
    assert number_requested == Enum.count(resulting_event.data.entries)
  end
end

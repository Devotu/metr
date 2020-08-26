defmodule LogTest do
  use ExUnit.Case

  alias Metr.Log
  alias Metr.CLI
  alias Metr.Event

  test "input read log" do
    assert :ok == CLI.process [{:log, 10}]
  end


  test "read log" do
    limit_requested = 5
    sent_event = Event.new([:read, :log], %{limit: limit_requested})
    [resulting_event] = Log.feed sent_event, nil
    assert [:list, :log, sent_event.id] == resulting_event.tags
    assert limit_requested == Enum.count(resulting_event.data.entries)
  end
end

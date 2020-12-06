defmodule LogTest do
  use ExUnit.Case

  alias Metr.Modules.Log
  alias Metr.Modules.CLI
  alias Metr.Event

  test "input read log" do
    assert :ok == CLI.process([{:log, 10}])
  end

  test "read log" do
    limit_requested = 5
    sent_event = Event.new([:read, :log], %{limit: limit_requested})
    [resulting_event] = Log.feed(sent_event, nil)
    assert [:list, :log, sent_event.id] == resulting_event.tags
    assert limit_requested == Enum.count(resulting_event.data.entries)

    log_events = Metr.read_global_log(limit_requested)
    assert limit_requested == Enum.count(log_events)
  end
end

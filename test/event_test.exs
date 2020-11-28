defmodule EventTest do
  use ExUnit.Case

  alias Metr.Event

  test "only errors" do
    regular_event = Event.new([:read, :log], %{limit: 3})
    error_event = Event.new([:error, :log], %{msg: "something is wrong"})

    assert [error_event] == Event.only_errors([regular_event, error_event])
  end
end

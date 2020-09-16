defmodule DataTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event


  test "log and retrieve by id" do
    module_name = "Test"
    id1 = "id1"
    id2 = "id2"

    Data.log_by_id(module_name, id1, Event.new([:correct], %{data: "you want this"}))
    Data.log_by_id(module_name, id2, Event.new([:error], %{data: "this is not right"}))
    Data.log_by_id(module_name, id1, Event.new([:correct], %{data: "you want this"}))
    Data.log_by_id(module_name, id1, Event.new([:correct], %{data: "you want this"}))

    entries = Data.read_log_by_id(module_name, id1)
    assert 3 == Enum.count(entries)

    Data.wipe_log(module_name, id1)
    Data.wipe_log(module_name, id2)

    {:error, :not_found} = Data.read_log_by_id(module_name, id1)
    {:error, :not_found} = Data.read_log_by_id(module_name, id2)
  end
end

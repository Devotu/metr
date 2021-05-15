defmodule DataTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event

  test "log and retrieve by id" do
    module = :data_test_log_and_retrieve
    id1 = "id1"
    id2 = "id2"

    Data.log_by_id(module, id1, Event.new([:correct], %{data: "you want this"}))
    Data.log_by_id(module, id2, Event.new([:error], %{data: "this is not right"}))
    Data.log_by_id(module, id1, Event.new([:correct], %{data: "you want this"}))
    Data.log_by_id(module, id1, Event.new([:correct], %{data: "you want this"}))

    entries = Data.read_log_by_id(id1, module)
    assert 3 == Enum.count(entries)

    Data.wipe_log(module, id1)
    Data.wipe_log(module, id2)

    {:error, :not_found} = Data.read_log_by_id(id1, module)
    {:error, :not_found} = Data.read_log_by_id(id2, module)
  end

  test "delimiter mixup" do
    module = :data_test_delimiter
    id = "id"

    # Becomes <<131, 98, 95, 192, 31, 42>> when turned into binary
    # <<42>> is same as first of log delimiter and this should not be a problem
    specific_time = 1_606_426_410
    specific_event = %Event{id: "dataTest_delimiter_mixup", time: specific_time}

    Data.log_by_id(module, id, Event.new([:correct], %{data: "first"}))
    Data.log_by_id(module, id, specific_event)
    Data.log_by_id(module, id, Event.new([:correct], %{data: "second"}))
    Data.log_by_id(module, id, Event.new([:correct], %{data: "third"}))

    entries = Data.read_log_by_id(id, module)
    assert 4 == Enum.count(entries)

    Data.wipe_log(module, id)

    {:error, :not_found} = Data.read_log_by_id(id, module)
  end
end

defmodule DataTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event

  test "delimiter mixup" do
    module = :data_test_delimiter
    id = "id"

    # Becomes <<131, 98, 95, 192, 31, 42>> when turned into binary
    # <<42>> is same as first of log delimiter and this should not be a problem
    specific_time = 1_606_426_410
    specific_event = %Event{id: "dataTest_delimiter_mixup", time: specific_time}

    Data.save_state_with_log(module, id, %{}, Event.new([:correct], %{data: "first"}))
    Data.save_state_with_log(module, id, %{}, specific_event)
    Data.save_state_with_log(module, id, %{}, Event.new([:correct], %{data: "second"}))
    Data.save_state_with_log(module, id, %{}, Event.new([:correct], %{data: "third"}))

    entries = Data.read_log_by_id(id, module)
    assert 4 == Enum.count(entries)

    Data.wipe_log(module, id)

    {:error, :not_found} = Data.read_log_by_id(id, module)
  end
end

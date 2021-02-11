defmodule UtilTest do
  use ExUnit.Case

  alias Metr.Util
  alias Metr.Time

  test "add timestamp to timestamp map" do
    timestamp_name = "Test"
    original_ts_map = %{timestamp_name => [Time.timestamp()]}
    one_more_ts_map = Util.stamp_ts_map(original_ts_map, timestamp_name)

    new_list_of_timestamps = one_more_ts_map[timestamp_name]
    assert 2 == Enum.count(new_list_of_timestamps)
    [original_ts, new_ts] = new_list_of_timestamps
    assert is_number(original_ts)
    assert is_number(new_ts)
  end
end

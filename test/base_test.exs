defmodule BaseTest do
  use ExUnit.Case

  alias Metr.Modules.Base
  alias Metr.Data
  alias Metr.Event
  alias Metr.Modules.Player

  test "exists" do
    assert false == Base.exist?("not yet created", "Player")
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Adam Base"}), nil)
    player_id = resulting_event.data.id
    assert true == Base.exist?(player_id, "Player")
    Data.wipe_test("Player", player_id)
  end

end

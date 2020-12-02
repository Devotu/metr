defmodule BaseTest do
  use ExUnit.Case

  alias Metr.Modules.Base
  alias Metr.Data
  alias Metr.Event
  alias Metr.Modules.Player

  test "verify id" do
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Adam Base"}), nil)
    player_id = resulting_event.data.id
    assert Base.verify_id(player_id, :player)
    assert Base.verify_id("not a correct id", :player)
    Data.wipe_test("Player", player_id)
  end

end

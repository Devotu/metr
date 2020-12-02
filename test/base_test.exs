defmodule BaseTest do
  use ExUnit.Case

  alias Metr.Modules.Base
  alias Metr.Data
  alias Metr.Event
  alias Metr.Modules.Player

  test "verify id" do
    [resulting_event] = Player.feed(Event.new([:create, :player], %{name: "Adam Base"}), nil)
    player_id = resulting_event.data.id
    assert Base.verified_id(player_id, "Player")
    assert not Base.verified_id("not a correct id", "Player")
    Data.wipe_test("Player", player_id)
  end

end

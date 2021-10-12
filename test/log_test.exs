defmodule LogTest do
  use ExUnit.Case

  alias Metr.Event

  test "only events" do
    player_id = TestHelper.init_only_player "Olof Metr"
    deck_id = TestHelper.init_only_deck "Oscar Metr", player_id

    deck_initial = Metr.read(deck_id, :deck)
    assert nil == deck_initial.rank

    Metr.alter_rank(deck_id, :up)

    deck_log = Metr.read_log(deck_id, :deck)
    assert deck_log |> Enum.all?(fn l -> Event.is(l) end)
  end
end

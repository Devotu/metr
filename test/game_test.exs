defmodule GameTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event
  alias Metr.Game
  alias Metr.HRC

  test "create game" do
    hcr = HRC.parse("""
    create game
      with
        part 1
        player_id erik
        and deck_id evil
        and power positive
        and fun bad
      with
        part 2
        player_id fredrik
        and deck_id fungus
      with winner 2
    """)
    assert is_struct(hcr)
    assert hcr.action == :create
    assert hcr.subject == :game
    assert hcr.details == %{winner: 2}
    assert hcr.parts ==
      [
        %{part: 1, details: %{deck_id: "evil", player_id: "erik", power: 1, fun: -2}},
        %{part: 2, details: %{deck_id: "fungus", player_id: "fredrik"}}
      ]

    [resulting_event] = Game.feed Event.new(hcr)
    assert [:game, :created] == resulting_event.tags
    assert ["erik", "fredrik"] == resulting_event.data.player_ids
    assert ["evil", "fungus"] == resulting_event.data.deck_ids
    assert is_bitstring(resulting_event.id)
    Data.wipe_state("Game", resulting_event.data.id)
  end
end

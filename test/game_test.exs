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
        player erik
        and deck evil
        and force positive
        and fun bad
      with
        part 2
        player fredrik
        and deck fungus
      with winner 2
    """)
    assert is_struct(hcr)
    assert hcr.action == :create
    assert hcr.subject == :game
    assert hcr.details == %{winner: 2}
    assert hcr.parts ==
      [
        %{part: 1, details: %{deck: "evil", player: "erik", force: 1, fun: -2}},
        %{part: 2, details: %{deck: "fungus", player: "fredrik"}}
      ]

    [resulting_event] = Game.feed Event.new(hcr)
    assert [:game, :created] == resulting_event.tags
    Data.wipe_state("Game", resulting_event.data.id)
  end
end

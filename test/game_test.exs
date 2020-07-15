defmodule GameTest do
  use ExUnit.Case

  alias Metr.HRC

  test "parse create game" do
    data = HRC.parse("""
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
    assert is_struct(data)
    assert data.action == :create
    assert data.subject == :game
    assert data.details == %{winner: 2}
    assert data.parts ==
      [
        %{part: 1, details: %{deck: "evil", player: "erik", force: 1, fun: -2}},
        %{part: 2, details: %{deck: "fungus", player: "fredrik"}}
      ]
  end
end

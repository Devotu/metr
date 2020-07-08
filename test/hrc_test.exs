defmodule HRCTest do
  use ExUnit.Case

  alias Metr.HRC

  test "parse create player" do
    data = HRC.parse("create player Adam")
    assert is_struct(data)
    assert data.predicate == :create
    assert data.subject == :player
    assert data.details == %{id: "Adam"}
  end

  test "parse create deck" do
    data = HRC.parse("create deck Rush with player_id adam")
    assert is_struct(data)
    assert data.predicate == :create
    assert data.subject == :deck
    assert data.details == %{id: "Rush", player_id: "adam"}
  end
end

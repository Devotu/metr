defmodule HRCTest do
  use ExUnit.Case

  alias Metr.HRC

  test "parse create player" do
    data = HRC.parse("create player Adam")
    assert is_struct(data)
    assert data.action == :create
    assert data.subject == :player
    assert data.details == %{id: "Adam"}
  end

  test "parse create deck" do
    data = HRC.parse("create deck Alpha with player_id adam")
    assert is_struct(data)
    assert data.action == :create
    assert data.subject == :deck
    assert data.details == %{id: "Alpha", player_id: "adam"}
  end

  test "parse create deck with colors" do
    data =
      HRC.parse("create deck with name Bravo and player_id bertil and color black and color red")

    assert is_struct(data)
    assert data.action == :create
    assert data.subject == :deck
    assert data.details == %{name: "Bravo", player_id: "bertil", colors: [:black, :red]}
  end

  test "parse list decks" do
    data = HRC.parse("list deck all")
    assert is_struct(data)
    assert data.action == :list
    assert data.subject == :deck
    assert data.details == %{}
  end
end

defmodule CliTest do
  use ExUnit.Case

  import Metr.CLI, only: [parse: 1, process: 1]

  alias Metr.Id
  alias Metr.Data

  test "parse" do
    assert [{:help, true}] == parse(["-h", ""])
    assert [{:input, "create player Testy"}] == parse(["-q", "create player Testy"])
    assert [{:input, "create player Testy"}] == parse(["--input", "create player Testy"])
  end


  test "create player" do
    player_name = "Adam"
    player_id = Id.hrid(player_name)
    assert :ok == process [{:input, "create player with name #{player_name}"}]
    assert Data.state_exists?("Player", player_id)
    Data.wipe_test("Player", player_id)
  end


  test "create deck" do
    player_name = "Bertil"
    player_id = Id.hrid(player_name)
    deck_name = "Alpha"
    deck_id = Id.hrid(deck_name)
    assert :ok == process [{:input, "create player with name #{player_name}"}]
    assert :ok == process [{:input, "create deck with name #{deck_name} and player_id #{player_id}"}]
    assert Data.state_exists?("Player", player_id)
    assert Data.state_exists?("Deck", deck_id)
    Data.wipe_test("Player", player_id)
    Data.wipe_test("Deck", deck_id)
  end


  test "fail create deck" do
    player_name = "Ceasar"
    player_id = Id.hrid(player_name)
    deck_name = "Bravo"
    deck_id = Id.hrid(deck_name)
    assert :ok == process [{:input, "create deck with name #{deck_name} and player_id #{player_id}"}]
    assert !Data.state_exists?("Player", player_id)
    assert !Data.state_exists?("Deck", deck_id)
  end


  #Not actually testing the stuff but forces the system to display the wanted output
  test "fail request format" do
    deck_name = "Charlie"
    deck_id = Id.hrid(deck_name)
    assert :ok == process [{:input, "create deck with name #{deck_name}"}]
    assert !Data.state_exists?("Deck", deck_id)
  end
end

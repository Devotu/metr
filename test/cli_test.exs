defmodule CliTest do
  use ExUnit.Case

  import Metr.CLI, only: [parse: 1, process: 1]

  alias Metr.TestUtil
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
    Data.wipe_state("Player", player_id)
    assert :ok == process [{:input, "create player with name #{player_name}"}]
    assert Data.state_exists?("Player", player_id)
    Data.wipe_state("Player", player_id)
  end
end

defmodule StateTest do
  use ExUnit.Case

  alias Metr.Event
  alias Metr.Modules.Input.PlayerInput
  alias Metr.Modules.State
  alias Metr.Modules.Player

  test "standoff read entity x" do
    player_id = "adam_state_fake_id"
    player_input = %PlayerInput{name: "Adam State"}
    player_create_event = Event.new(
      [:create, :player],
      %{
        id: player_id,
        input: player_input
      }
    )

    read_task = Task.async(fn -> Metr.read(player_id, :player) end)
    :timer.sleep(50)
    Player.feed(player_create_event, nil)

    assert {:error, "player adam_state_fake_id not found"} != Task.await(read_task)

    TestHelper.wipe_test(:player, player_id)
  end

  test "standoff fail read entity x" do
    player_id = "bertil_state_fake_id"
    player_input = %PlayerInput{name: "Bertil State"}
    player_create_event = Event.new(
      [:create, :player],
      %{
        id: player_id,
        input: player_input
      }
    )

    read_task = Task.async(fn -> Metr.read(player_id, :player) end)
    :timer.sleep(500)
    Player.feed(player_create_event, nil)

    assert {:error, "player bertil_state_fake_id not found"} == Task.await(read_task)

    TestHelper.wipe_test(:player, player_id)
  end
end

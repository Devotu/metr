defmodule Metr do

  alias Metr.Event
  alias Metr.Router


  def list_players() do
    #Start listener
    listening_task = Task.async(fn ->
      listen()
    end)

    #Fire ze missiles
    Event.new([:list, :player], %{response_pid: listening_task.pid})
    |> Router.input()

    #Await response
    Task.await(listening_task)
  end


  def listen() do
    receive do
      msg ->
        msg
    end
  end


  ## feed
  def feed(%Event{tags: [:players, response_pid]} = event) when is_pid(response_pid) do
    send response_pid, event.data.players
    []
  end


  def feed(_) do
    []
  end
end

defmodule Metr do

  alias Metr.Event
  alias Metr.Router


  ## api
  def list_players() do
    list(:player)
  end

  def list_decks() do
    list(:deck)
  end

  def list_games() do
    list(:game)
  end



  ## private
  defp list(type) when is_atom(type) do
    #Start listener
    listening_task = Task.async(&listen/0)

    #Fire ze missiles
    Event.new([:list, type], %{response_pid: listening_task.pid})
    |> Router.input()

    #Await response
    Task.await(listening_task)
  end

  defp listen() do
    receive do
      msg ->
        msg
    end
  end



  ## feed
  def feed(%Event{tags: [type, response_pid]} = event) when is_atom(type) and is_pid(response_pid) do
    send response_pid, event.data[type]
    []
  end

  def feed(_) do
    []
  end
end

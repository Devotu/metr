defmodule Metr do

  alias Metr.Event
  alias Metr.Router

  @default_game %{
    :fun_1 => nil, :fun_2 => nil,
    :power_1 => nil, :power_2 => nil,
    :winner => 0
    }

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



  def create_game(%{
    :deck_1 => d1, :deck_2 => d2,
    :fun_1 => f1, :fun_2 => f2,
    :player_1 => p1, :player_2 => p2,
    :power_1 => s1, :power_2 => s2,
    :winner => w
  }) do

    data = %{
      winner: w,
      parts: [
        %{part: 1, details: %{deck_id: d1, player_id: p1, power: s1, fun: f1}},
        %{part: 2, details: %{deck_id: d2, player_id: p2, power: s2, fun: f2}},
      ]
    }

    create(:game, data)
  end

  def create_game(game_data) when is_map(game_data) do
    Map.merge(@default_game, game_data)
    |> create_game()
  end


  def delete_game(game_id) do
    #Start listener
    listening_task = Task.async(&listen/0)

    #Fire ze missiles
    Event.new([:delete, :game], %{game_id: game_id})
    |> Router.input(listening_task.pid)

    #Await response
    Task.await(listening_task)
  end


  ## private
  defp list(type) when is_atom(type) do
    #Start listener
    listening_task = Task.async(&listen/0)

    #Fire ze missiles
    Event.new([:list, type])
    |> Router.input(listening_task.pid)

    #Await response
    Task.await(listening_task)
  end


  defp create(type, data) when is_atom(type) do
    #Start listener
    listening_task = Task.async(&listen/0)

    #Fire ze missiles
    Event.new([:create, type], data)
    |> Router.input(listening_task.pid)

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
  #by type
  def feed(%Event{tags: [type, response_pid]} = event, _orepp) when is_atom(type) and is_pid(response_pid) do
    send response_pid, event.data[type]
    []
  end

  #by id
  def feed(%Event{tags: [type, _status, response_pid]} = event, _orepp) when is_atom(type) and is_pid(response_pid) do
    send response_pid, event.data.id
    []
  end

  #by id failure
  def feed(%Event{tags: [type, :not, _status, response_pid]} = _event, _orepp) when is_atom(type) and is_pid(response_pid) do
    send response_pid, :error
    []
  end

  def feed(_event, _orepp) do
    []
  end
end

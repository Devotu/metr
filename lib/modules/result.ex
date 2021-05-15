defmodule Metr.Modules.Result do
  defstruct id: "",
            time: 0,
            game_id: "",
            player_id: "",
            deck_id: "",
            place: nil,
            power: nil,
            fun: nil,
            tags: []

  use GenServer

  alias Metr.Data
  alias Metr.Id
  alias Metr.Event
  alias Metr.Modules.Deck
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Stately
  alias Metr.Modules.Input.ResultInput

  @atom :result

  def create(%ResultInput{} = data, %Event{} = event) do
    id = Id.guid()

    case verify_input(data) do
      {:error, e} -> {:error, e}
      {:ok} -> init_process(id, data, event)
    end
  end

  defp init_process(id, %ResultInput{} = data, %Event{} = event) do
    process_name = Data.genserver_id(@atom, id)
    # Start genserver
    case GenServer.start(Metr.Modules.Result, {id, data, event}, name: process_name) do
      {:ok, _pid} -> {:ok, id}
      {:error, e} -> {:error, e}
    end
  end


  defp verify_input(%ResultInput{} = data) do
    p = verify_player(data.player_id)
    d = verify_deck(data.deck_id)
    g = verify_game(data.game_id)

    case [p,d,g] do
      [{:error, e}, _, _] -> {:error, e}
      [_, {:error, e}, _] -> {:error, e}
      [_, _, {:error, e}] -> {:error, e}
      _ -> {:ok}
    end
  end

  defp verify_player(player_id) do
    case Player.exist?(player_id) do
      true -> {:ok}
      false -> {:error, "player #{player_id} not found"}
    end
  end

  defp verify_deck(deck_id) do
    case Deck.exist?(deck_id) do
      true -> {:ok}
      false -> {:error, "deck #{deck_id} not found"}
    end
  end

  defp verify_game(game_id) when is_bitstring(game_id) , do: {:ok}
  defp verify_game(nil), do: {:error, "game id cannot be nil"}
  defp verify_game(game_id), do: {:error, "game id #{game_id} is not valid"}

  defp from_input(%ResultInput{} = data, id, created_time) do
    %Result{
      id: id,
      time: created_time,
      player_id: data.player_id,
      deck_id: data.deck_id,
      game_id: data.game_id,
      place: data.place,
      power: data.power,
      fun: data.fun,
      tags: data.tags
    }
  end

  def feed(%Event{id: _event_id, keys: [:list, @atom], data: %{ids: ids}}, repp)
      when is_list(ids) do
    results = Enum.map(ids, &read/1)
    [Event.new([@atom, :list, repp], %{out: results})]
  end

  def feed(%Event{id: _event_id, keys: [:read, @atom], data: %{result_id: id}}, repp) do
    result = read(id)
    [Event.new([@atom, :read, repp], %{out: result})]
  end

  def feed(_event, _orepp) do
    []
  end

  def read(id) do
    Stately.read(id, @atom)
    # Data.recall_state(@atom, id)
  end

  def delete(id) do
    Data.wipe_state(id, @atom)
  end

  ## gen
  @impl true
  def init({id, %ResultInput{} = data, %Event{} = event}) do
    state = from_input(data, id, event.time)
    :ok = Data.save_state_with_log(@atom, id, state, event)
    {:ok, state}
  end

  def init(%Result{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, @atom]}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(
        %{keys: [:tagged], data: %{id: id, tag: tag}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    :ok = Data.save_state_with_log(@atom, id, state, event)
    {:reply, "#{@atom} #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

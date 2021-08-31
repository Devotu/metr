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
  alias Metr.Event
  alias Metr.Modules.Result
  alias Metr.Modules.State
  alias Metr.Modules.Input.ResultInput

  @atom :result

  def feed(
    %Event{
      keys: [:create, @atom],
      data: %{id: id, input: _input}
      } = event,
    repp
  ) do

    State.create(id, @atom, event, repp)
  end

  def feed(_event, _orepp) do
    []
  end

  def read(id) do
    State.read(id, @atom)
    # Data.recall_state(@atom, id)
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
    case State.exist?(player_id, :player) do
      true -> {:ok}
      false -> {:error, "player #{player_id} not found"}
    end
  end

  defp verify_deck(deck_id) do
    case State.exist?(deck_id, :deck) do
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


  ## gen
  @impl true
  def init(%Event{} = event) do
    id = event.data.id
    input = event.data.input

    case verify_input(input) do
      {:error, e} ->
        IO.inspect e, label: "Result - Input error"
        {:stop, e}
      {:ok} ->
        state = from_input(input, id, event.time)
        case Data.save_state_with_log(@atom, id, state, event) do
          {:error, e} ->
            {:stop, e}
          _ ->
            {:ok, state}
        end
    end
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
        %Event{keys: [@atom, :tagged], data: %{id: id, tag: tag} = event},
        _from,
        state
      ) do

    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    case Data.save_state_with_log(@atom, id, new_state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, new_state}
    end
    {:reply, "Deck #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

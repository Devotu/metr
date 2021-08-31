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
    state = from_input(input, id, event.time)

    case Data.save_state_with_log(@atom, id, state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:ok, state}
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

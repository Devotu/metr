defmodule Metr.Modules.Result do
  defstruct id: "",
            time: 0,
            game_id: "",
            player_id: "",
            deck_id: "",
            place: nil,
            power: nil,
            fun: nil,
            tags: [],
            badges: %{}

  use GenServer

  alias Metr.Data
  alias Metr.Id
  alias Metr.Event
  alias Metr.Modules.Result
  alias Metr.Modules.Stately
  alias Metr.Util
  alias Metr.Time

  @name __ENV__.module |> Stately.module_to_name()

  def create(%Result{} = result, event) do
    id = Id.guid()

    state =
      result
      |> Map.put(:id, id)
      |> Map.put(:time, Time.timestamp())
      |> verify_data()

    case state do
      {:error, error} -> {:error, error}
      _ -> {Data.save_state_with_log(__ENV__.module, id, state, event), state}
    end
  end

  defp verify_data(%Result{} = r) do
    case data_is_valid(r) do
      true -> r
      false -> {:error, "Invalid results data"}
    end
  end

  defp data_is_valid(%Result{} = r) do
    valid_id(r.id) and
      valid_id(r.deck_id) and
      valid_id(r.player_id) and
      valid_number(r.power) and
      valid_number(r.place) and
      valid_number(r.fun) and
      valid_time(r.time)
  end

  def feed(%Event{id: _event_id, keys: [:list, :result], data: %{ids: ids}}, repp)
      when is_list(ids) do
    results = Enum.map(ids, &read/1)
    [Event.new([:results, repp], %{results: results})]
  end

  def feed(%Event{id: _event_id, keys: [:read, :result], data: %{result_id: id}}, repp) do
    result = read(id)
    [Event.new([:result, :read, repp], %{out: result})]
  end

  def feed(_event, _orepp) do
    []
  end

  def read(id) do
    Data.recall_state(__ENV__.module, id)
  end

  def delete(id) do
    Data.wipe_state(__ENV__.module, id)
  end

  defp valid_id(nil), do: false
  defp valid_id(x) when is_bitstring(x), do: true
  defp valid_id(_), do: false

  defp valid_number(nil), do: true
  defp valid_number(x) when is_number(x), do: true
  defp valid_number(_), do: false

  defp valid_time(nil), do: false
  defp valid_time(0), do: false
  defp valid_time(x) when is_number(x), do: true
  defp valid_time(_), do: false

  ## gen
  @impl true
  def init(%Result{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, :result]}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(
        %{keys: [:tagged], data: %{id: id, tag: tag}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "#{@name} #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:badged], data: %{id: id, badge: badge}, event: event},
        _from,
        state
      ) do
    new_state = Map.put(state, :badges, Util.stamp_ts_map(state.badges, badge))
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "#{@name} #{id} badges altered to #{Kernel.inspect(new_state.badges)}", new_state}
  end
end

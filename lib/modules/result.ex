defmodule Metr.Result do
  defstruct id: "",
            time: 0,
            game_id: "",
            player_id: "",
            deck_id: "",
            place: nil,
            power: nil,
            fun: nil

  alias Metr.Data
  alias Metr.Id
  alias Metr.Event
  alias Metr.Result
  alias Metr.Time

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
    IO.inspect(r, label: "result")
    valid_id(r.id)
    and valid_id(r.deck_id)
    and valid_id(r.player_id)
    and valid_number(r.power)
    and valid_number(r.place)
    and valid_number(r.fun)
    and valid_time(r.time)
  end

  def feed(%Event{id: _event_id, tags: [:list, :result], data: %{ids: ids}}, repp)
      when is_list(ids) do
    results = Enum.map(ids, &read/1)
    [Event.new([:results, repp], %{results: results})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :result]}, repp) do
    results =
      Data.list_ids(__ENV__.module)
      |> Enum.map(&read/1)

    [Event.new([:results, repp], %{results: results})]
  end

  def feed(%Event{id: _event_id, tags: [:read, :result], data: %{result_id: id}}, repp) do
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


  defp valid_id(nil), do: :false
  defp valid_id(x) when is_bitstring(x), do: :true
  defp valid_id(_), do: :false

  defp valid_number(nil), do: :true
  defp valid_number(x) when is_number(x), do: :true
  defp valid_number(_), do: :false

  defp valid_time(nil), do: :false
  defp valid_time(0), do: :false
  defp valid_time(x) when is_number(x), do: :true
  defp valid_time(_), do: :false
end

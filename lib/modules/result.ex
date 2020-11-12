defmodule Metr.Result do
  defstruct id: "", time: 0, game_id: "", player_id: "", deck_id: "", place: nil, power: nil, fun: nil

  alias Metr.Data
  alias Metr.Id
  alias Metr.Event
  alias Metr.Result

  def create(%Result{} = result, event) do
    id = Id.guid()
    state = result
      |> verify_data()
      |> Map.put(:id, id)

    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:ok, state}
  end

  defp verify_data(%Result{} = r) do
    r
  end

  def feed(%Event{id: _event_id, tags: [:list, :result], data: %{ids: ids}}, repp) when is_list(ids) do
    results = Enum.map(ids, &read/1)
    [Event.new([:results, repp], %{results: results})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :result]}, repp) do
    results = Data.list_ids(__ENV__.module)
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
end

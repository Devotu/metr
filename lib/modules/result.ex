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

  def feed(%Event{id: _event_id, tags: [:list, :result]}, repp) do
    results = Data.list_ids(__ENV__.module)
    |> Enum.map(fn id -> read(id) end)
    |> IO.inspect(label: "result - results")
    [Event.new([:results, repp], %{results: results})]
  end

  def feed(_event, _orepp) do
    []
  end




  def read(id) do
    Data.recall_state(__ENV__.module, id)
  end
end
defmodule Metr.Modules.State do
  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.Player

  def feed(
        %Event{id: _event_id, keys: [:create, module], data: input} = event,
        repp
      ) do

    id = Id.guid() |> IO.inspect(label: "state - id")
    process_name = Data.genserver_id(id, module) |> IO.inspect(label: "state - process name")
    target_module = select_target_module(module) |> IO.inspect(label: "state - process module")

    case GenServer.start(target_module, {id, input, event}, name: process_name) do
      {:ok, _pid} ->
        [:player, :created, nil]
        [Event.new([module, :created, repp], %{out: id})]
      {:error, e} ->
        [Event.error_to_event(e, repp)]
    end
  end

  def feed(_event, _repp) do
    []
  end


  defp select_target_module(entity) when is_atom(entity) do
    case entity do
      :player -> Player
      :deck -> Deck
      :game -> Game
      :match -> Match
      :result -> Result
      :tag -> Tag
      _ -> {:error, "#{Kernel.inspect(entity)} is not a valid atom selecting entity"}
    end
  end
end

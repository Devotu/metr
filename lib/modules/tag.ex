defmodule Metr.Modules.Tag do
  defstruct id: "", name: "", tagged: []

  use GenServer

  alias Metr.Modules.Stately
  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Modules.Tag

  @name __ENV__.module |> Stately.module_to_name()
  @valid_tag_length 20

  def feed(
        %Event{id: _event_id, keys: [:tag, module_atom], data: %{id: module_id, tag: tag} = data} = event,
        repp
      ) do

    target_module_name = Stately.select_module_name(module_atom)

    validation = :ok
    |> is_valid_tag(tag)
    |> is_valid_target(target_module_name, module_id)
    |> is_not_duplicate(target_module_name, module_id, tag)

    case {validation, exist?(tag)} do
      {:ok, false} ->
        state = %Tag{id: Id.hrid(tag), name: tag, tagged: [module_id]}
        propagating_event = Event.new([module_atom, :tagged], %{id: module_id, tag: tag})
        Stately.create(@name, state, event)
        |> Stately.out_to_event(@name, [:created, repp])
        |> List.wrap()
        |> Enum.concat([propagating_event])
      {:ok, true} ->
        propagating_event = Event.new([module_atom, :tagged], %{id: module_id, tag: tag})
        Stately.update(tag, @name, [:tagged], %{id: module_id}, event)
        |> Stately.out_to_event(@name, [:altered, repp])
        |> List.wrap()
        |> Enum.concat([propagating_event])
      {{:error, e}, _} ->
        [Event.new([module_atom, :error, repp], %{msg: e})]
    end
  end

  def feed(%Event{id: _event_id, keys: [module_atom, :tagged], data: %{id: _id, tag: _tag}} = event, repp) do
    Stately.update(event.data.id, Stately.select_module_name(module_atom), [:tagged], event.data, event)
    |> Stately.out_to_event(Stately.select_module_name(module_atom), [module_atom, :tagged])
    |> List.wrap()
  end

  def feed(_event, _orepp) do
    []
  end


  def is_valid_tag({:error, e}, _tag), do: {:error, e}
  def is_valid_tag(:ok, tag), do: is_valid_tag(tag)
  def is_valid_tag(""), do: {:error, "tag cannot be empty"}
  def is_valid_tag(tag) when is_bitstring(tag) do
    case String.length(tag) < @valid_tag_length do
      true -> :ok
      false -> {:error, "tag to long"}
    end
  end
  def is_valid_tag(tag) when is_nil(tag), do: {:error, "tag cannot be nil"}
  def is_valid_tag(_tag), do: {:error, "tag must be string"}

  defp is_valid_target({:error, e}), do: {:error, e}
  defp is_valid_target(:ok, module_name, module_id) do
    case Stately.exist?(module_id, module_name) do
      true -> :ok
      false -> {:error, "tag target not found"}
    end
  end

  defp is_not_duplicate({:error, e}), do: {:error, e}
  defp is_not_duplicate(:ok, module_name, module_id, tag) do
    target = Stately.read(module_id, module_name)
    case Enum.member?(target.tags, tag) do
      true -> {:error, "duplicate tag found"}
      false -> :ok
    end
  end

  # def feed(
  #       %Event{
  #         id: _event_id,
  #         keys: [:deck, :created, _orepp] = keys,
  #         data: %{id: deck_id, tag_id: id}
  #       } = event,
  #       repp
  #     ) do
  #   [
  #     Stately.update(id, @name, keys, %{id: deck_id, tag_id: id}, event)
  #     |> Stately.out_to_event(@name, [:altered, repp])
  #   ]
  # end


  ## module
  def read(id) do
    Stately.read(id, @name)
  end

  def exist?(id) do
    Stately.exist?(id, @name)
  end

  def module_name() do
    @name
  end

  ## gen
  def init(%Tag{} = state) do
    {:ok, state}
  end

  # @impl true
  # def handle_call(
  #       %{keys: [:deck, :created, _orepp], data: %{id: deck_id, tag_id: id}, event: event},
  #       _from,
  #       state
  #     ) do
  #   new_state = Map.update!(state, :decks, &(&1 ++ [deck_id]))
  #   :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
  #   {:reply, "Deck #{deck_id} added to tag #{id}", new_state}
  # end

  # @impl true
  # def handle_call(
  #       %{keys: [:game, :created, _orepp], data: %{id: result_id, tag_id: id}, event: event},
  #       _from,
  #       state
  #     ) do
  #   new_state = Map.update!(state, :results, &(&1 ++ [result_id]))
  #   :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
  #   {:reply, "Result #{result_id} added to tag #{id}", new_state}
  # end

  # @impl true
  # def handle_call(
  #       %{keys: [:match, :created, _orepp], data: %{id: match_id, tag_id: id}, event: event},
  #       _from,
  #       state
  #     ) do
  #   new_state = Map.update!(state, :matches, &(&1 ++ [match_id]))
  #   :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
  #   {:reply, "Match #{match_id} added to tag #{id}", new_state}
  # end

  # @impl true
  # def handle_call(
  #       %{keys: [:game, :deleted, _orepp], data: %{id: result_id, tag_id: id}, event: event},
  #       _from,
  #       state
  #     ) do
  #   new_state = Map.update!(state, :results, fn results -> List.delete(results, result_id) end)
  #   :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
  #   {:reply, "Game #{result_id} removed from tag #{id}", new_state}
  # end

  @impl true
  def handle_call(%{keys: [:read, :tag]}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(%{keys: [:tagged], data: %{id: id}}, _from, state) do
    new_state = Map.update!(state, :tagged, &(&1 ++ [id]))
    {:reply, state, new_state}
  end
end

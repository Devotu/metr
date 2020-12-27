defmodule Metr.Modules.Tag do
  defstruct id: "", name: "", tagged: []

  use GenServer

  alias Metr.Modules.Stately
  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Modules.Tag
  alias Metr.Modules.Result
  alias Metr.Util

  @name __ENV__.module |> Stately.module_to_name()
  @valid_tag_length 20

  def feed(
        %Event{id: _event_id, tags: [:tag, module_atom], data: %{id: module_id, tag: tag} = data} = event,
        repp
      ) do

        #check if duplicate
        #check if exist
        # yes -> update
        # no  -> create


        validation = :ok
        |> is_valid_tag(tag)
        |> is_valid_target(module_atom, module_id)

    case validation do
      :ok ->
        state = %Tag{id: Id.hrid(tag), name: tag, tagged: [module_id]}
        Stately.create(@name, state, event)
        |> Stately.out_to_event(@name, [:created, repp])
        |> List.wrap()
      {:error, e} ->
        [Event.new([:player, :error, repp], %{msg: e})]
    end
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
  defp is_valid_target(:ok, module_atom, module_id) when is_atom(module_atom) and is_bitstring(module_id) do
    case Stately.exist?(module_id, module_atom) do
      true -> :ok
      false -> {:error, "tag target not found"}
    end
  end







  def feed(
        %Event{
          id: _event_id,
          tags: [:deck, :created, _orepp] = tags,
          data: %{id: deck_id, tag_id: id}
        } = event,
        repp
      ) do
    [
      Stately.update(id, @name, tags, %{id: deck_id, tag_id: id}, event)
      |> Stately.out_to_event(@name, [:altered, repp])
    ]
  end

  def feed(
        %Event{
          id: _event_id,
          tags: [:game, :created, _orepp] = tags,
          data: %{result_ids: result_ids}
        } = event,
        repp
      ) do
    tag_result_ids =
      result_ids
      |> Enum.map(fn result_id -> Result.read(result_id) end)
      |> Enum.map(fn r -> {r.tag_id, r.id} end)

    # for each participant
    # call update
    Enum.reduce(
      tag_result_ids,
      [],
      fn {id, result_id}, acc ->
        acc ++
          [
            Stately.update(id, @name, tags, %{id: result_id, tag_id: id}, event)
            |> Stately.out_to_event(@name, [:altered, repp])
          ]
      end
    )
  end

  def feed(
        %Event{
          id: _event_id,
          tags: [:game, :deleted, _orepp] = tags,
          data: %{results: result_ids}
        } = event,
        repp
      ) do
    # for each tag find connections to this game
    tag_result_ids =
      Data.list_ids(__ENV__.module)
      |> Enum.map(fn id -> read(id) end)
      |> Enum.filter(fn p -> Util.has_member?(p.results, result_ids) end)
      |> Enum.map(fn p -> {p.id, Util.find_first_common_member(p.results, result_ids)} end)

    # call update
    Enum.reduce(tag_result_ids, [], fn {id, result_id}, acc ->
      acc ++
        [
          Stately.update(id, @name, tags, %{id: result_id, tag_id: id}, event)
          |> Stately.out_to_event(@name, [:altered, repp])
        ]
    end)
  end

  def feed(
        %Event{
          id: _event_id,
          tags: [:match, :created, _orepp] = tags,
          data: %{id: match_id, tag_ids: tag_ids}
        } = event,
        repp
      ) do
    # for each participant
    # call update
    Enum.reduce(tag_ids, [], fn id, acc ->
      acc ++
        [
          Stately.update(id, @name, tags, %{id: match_id, tag_id: id}, event)
          |> Stately.out_to_event(@name, [:altered, repp])
        ]
    end)
  end

  def feed(%Event{id: _event_id, tags: [:read, :tag], data: %{tag_id: id}}, repp) do
    tag = read(id)
    [Event.new([:tag, :read, repp], %{out: tag})]
  end

  def feed(%Event{id: _event_id, tags: [:read, :log, :tag], data: %{tag_id: id}}, repp) do
    events = Data.read_log_by_id("Tag", id)
    [Event.new([:tag, :log, :read, repp], %{out: events})]
  end

  def feed(%Event{id: _event_id, tags: [:list, :tag]}, repp) do
    tags =
      Data.list_ids(__ENV__.module)
      |> Enum.map(fn id -> read(id) end)

    [Event.new([:tags, repp], %{tags: tags})]
  end

  def feed(_event, _orepp) do
    []
  end

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

  @impl true
  def handle_call(
        %{tags: [:deck, :created, _orepp], data: %{id: deck_id, tag_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :decks, &(&1 ++ [deck_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Deck #{deck_id} added to tag #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{tags: [:game, :created, _orepp], data: %{id: result_id, tag_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :results, &(&1 ++ [result_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Result #{result_id} added to tag #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{tags: [:match, :created, _orepp], data: %{id: match_id, tag_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :matches, &(&1 ++ [match_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Match #{match_id} added to tag #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{tags: [:game, :deleted, _orepp], data: %{id: result_id, tag_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :results, fn results -> List.delete(results, result_id) end)
    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Game #{result_id} removed from tag #{id}", new_state}
  end

  @impl true
  def handle_call(%{tags: [:read, :tag]}, _from, state) do
    {:reply, state, state}
  end
end

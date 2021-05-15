defmodule Metr.Modules.Tag do
  defstruct id: "", name: "", tagged: []

  use GenServer

  alias Metr.Modules.Stately
  alias Metr.Event
  alias Metr.Id
  alias Metr.Time
  alias Metr.Modules.Tag


  @atom :tag
  @valid_tag_length 20

  def feed(
        %Event{id: _event_id, keys: [@atom, module_atom], data: %{id: module_id, tag: tag}} =
          event,
        repp
      ) do
    target_module_name = Stately.select_module_name(module_atom)

    validation =
      :ok
      |> is_valid_tag(tag)
      |> is_valid_target(target_module_name, module_id)
      |> is_not_duplicate(target_module_name, module_id, tag)

    case {validation, exist?(tag)} do
      {:ok, false} ->
        state = %Tag{id: Id.hrid(tag), name: tag, tagged: [{module_id, Time.timestamp()}]}
        propagating_event = Event.new([module_atom, :tagged], %{id: module_id, tag: tag})

        Stately.create(@atom, state, event)
        |> Stately.out_to_event(@atom, [:created, repp])
        |> List.wrap()
        |> Enum.concat([propagating_event])

      {:ok, true} ->
        propagating_event = Event.new([module_atom, :tagged], %{id: module_id, tag: tag})

        Stately.update(tag, @atom, [:tagged], %{id: module_id}, event)
        |> Stately.out_to_event(@atom, [:altered, repp])
        |> List.wrap()
        |> Enum.concat([propagating_event])

      {{:error, e}, _} ->
        [Event.new([module_atom, :error, repp], %{msg: e})]
    end
  end

  def feed(
        %Event{id: _event_id, keys: [module_atom, :tagged], data: %{id: _id, tag: _tag}} = event,
        _repp
      ) do
    Stately.update(
      event.data.id,
      Stately.select_module_name(module_atom),
      [:tagged],
      event.data,
      event
    )
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

  defp is_valid_target(:ok, module_name, module_id) do
    case Stately.exist?(module_id, module_name) do
      true -> :ok
      false -> {:error, "tag target not found"}
    end
  end

  defp is_not_duplicate(:ok, module_name, module_id, tag) do
    target = Stately.read(module_id, module_name)

    case Enum.member?(target.tags, tag) do
      true -> {:error, "duplicate tag #{tag} found on #{module_name} #{module_id}"}
      false -> :ok
    end
  end

  ## module
  def read(id) do
    Stately.read(id, @atom)
  end

  def exist?(id) do
    Stately.exist?(id, @atom)
  end

  def module_name() do
    @atom
  end

  ## gen
  @impl true
  def init(%Tag{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, @atom]}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(%{keys: [:tagged], data: %{id: id}}, _from, state) do
    new_state = Map.update!(state, :tagged, &(&1 ++ [{id, Time.timestamp()}]))
    {:reply, state, new_state}
  end
end

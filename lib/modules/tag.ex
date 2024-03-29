defmodule Metr.Modules.Tag do
  defstruct id: "", name: "", tagged: []

  use GenServer

  alias Metr.Data
  alias Metr.Event
  alias Metr.Id
  alias Metr.Modules.State
  alias Metr.Modules.Tag
  alias Metr.Time

  @atom :tag
  @valid_tag_length 20

  def feed(
        %Event{id: _event_id, keys: [@atom, target_module], data: %{id: target_id, tag: tag}} =
          event,
        repp
      ) do

        IO.inspect event, label: "tag"

    validation =
      :ok
      |> is_valid_tag(tag)
      |> is_valid_target(target_module, target_id)
      |> is_not_duplicate(target_module, target_id, tag)

    id = Id.hrid(tag)
    tag_exist? = State.exist?(id, :tag)
    propagating_event = Event.new([target_module, :tagged], %{id: target_id, tag: tag})

    IO.inspect tag_exist?, label: "tag exist"
    IO.inspect propagating_event, label: "tag prop"

    case {validation, tag_exist?} do
      {:ok, false} ->
        IO.puts("tag - ok, false")
        create_response_event = State.create(id, @atom, event, repp)
        case create_response_event do
          [%Event{data: %{cause: _cause}}] = error_event ->
            error_event
          [e] ->
            [e, propagating_event]
        end
      {:ok, true} ->
        IO.puts("tag - ok, true")
        case State.update(id, :tag, event) do
          :ok ->
            [Event.new([:tag, :created, repp], %{out: id}), propagating_event]
          x ->
            x
        end
      {{:error, e}, _} ->
        IO.puts("tag - error")
        [Event.error_to_event(e, repp)]
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

  defp is_valid_target(:ok, module_name, target_id) do
    case State.exist?(target_id, module_name) do
      true -> :ok
      false -> {:error, "tag target not found"}
    end
  end

  defp is_not_duplicate(:ok, module_name, target_id, tag) do
    target = State.read(target_id, module_name)

    case Enum.member?(target.tags, tag) do
      true -> {:error, "duplicate tag #{tag} found on #{module_name} #{target_id}"}
      false -> :ok
    end
  end

  defp tag_tuple(target_module, target_id) do
    {target_module, target_id, Time.timestamp()}
  end

  ## gen
  @impl true
  def init(%Event{} = event) do
    id = Id.hrid(event.data.tag)
    target_id = event.data.id
    tag_name = event.data.tag
    [@atom, target_module] = event.keys

    state = %Tag{
      id: id,
      name: tag_name,
      tagged: [tag_tuple(target_module, target_id)]
    }

    case Data.save_state_with_log(@atom, id, state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:ok, state}
    end
  end

  @impl true
  def init(%Tag{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, @atom]}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(%Event{keys: [:tag, target_module], data: %{id: target_id}} = event, _from, state) do
    new_state = state
      |> Map.update!(
        :tagged,
        &(&1 ++ [tag_tuple(target_module, target_id)])
      )

    case Data.save_state_with_log(@atom, state.id, new_state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:ok, new_state}
    end
    # {:reply, "#{target_id} added to tagged by #{state.name}", new_state}
  end
end

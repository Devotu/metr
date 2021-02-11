defmodule Metr.Modules.Badge do
  defstruct id: "", name: "", badged: %{}

  use GenServer

  alias Metr.Modules.Stately
  alias Metr.Event
  alias Metr.Id
  alias Metr.Time
  alias Metr.Modules.Badge

  @name __ENV__.module |> Stately.module_to_name()
  @valid_badge_length 20

  def feed(
        %Event{id: _event_id, keys: [:badge, module_atom], data: %{id: module_id, badge: badge}} =
          event,
        repp
      ) do
    target_module_name = Stately.select_module_name(module_atom)

    validation =
      :ok
      |> is_valid_badge(badge)
      |> is_valid_target(target_module_name, module_id)

      # |> is_not_duplicate(target_module_name, module_id, badge)
      # |> IO.inspect(label: "badge - is duplicate?")

    case {validation, exist?(badge)} do
      {:ok, false} ->
        state = %Badge{id: Id.hrid(badge), name: badge, badged: %{module_id => [Time.timestamp()]}}
        propagating_event = Event.new([module_atom, :badged], %{id: module_id, badge: badge})

        Stately.create(@name, state, event)
        |> Stately.out_to_event(@name, [:created, repp])
        |> List.wrap()
        |> Enum.concat([propagating_event])

      {:ok, true} ->
        propagating_event = Event.new([module_atom, :badged], %{id: module_id, badge: badge})

        Stately.update(badge, @name, [:badged], %{id: module_id}, event)
        |> Stately.out_to_event(@name, [:altered, repp])
        |> List.wrap()
        |> Enum.concat([propagating_event])

      {{:error, e}, _} ->
        [Event.new([module_atom, :error, repp], %{msg: e})]
    end
  end

  def feed(
        %Event{id: _event_id, keys: [module_atom, :badged], data: %{id: _id, badge: _badge}} = event,
        _repp
      ) do
    Stately.update(
      event.data.id,
      Stately.select_module_name(module_atom),
      [:badged],
      event.data,
      event
    )
    |> Stately.out_to_event(Stately.select_module_name(module_atom), [module_atom, :badged])
    |> List.wrap()
  end

  def feed(_event, _orepp) do
    []
  end

  def is_valid_badge({:error, e}, _badge), do: {:error, e}
  def is_valid_badge(:ok, badge), do: is_valid_badge(badge)
  def is_valid_badge(""), do: {:error, "badge cannot be empty"}

  def is_valid_badge(badge) when is_bitstring(badge) do
    case String.length(badge) < @valid_badge_length do
      true -> :ok
      false -> {:error, "badge to long"}
    end
  end

  def is_valid_badge(badge) when is_nil(badge), do: {:error, "badge cannot be nil"}
  def is_valid_badge(_badge), do: {:error, "badge must be string"}

  defp is_valid_target({:error, e}), do: {:error, e}
  defp is_valid_target(:ok, module_name, module_id) do
    case Stately.exist?(module_id, module_name) do
      true -> :ok
      false -> {:error, "badge target not found"}
    end
  end

  # defp is_not_duplicate({:error, e}), do: {:error, e}

  # defp is_not_duplicate(:ok, module_name, module_id, badge) do
  #   target = Stately.read(module_id, module_name)

  #   IO.inspect(target, label: "badge - target")

  #   case Enum.member?(target.badges, badge) do
  #     true -> {:error, "duplicate badge #{badge} found on #{module_name} #{module_id}"}
  #     false -> :ok
  #   end
  # end

  # defp add_badge(%Badge{} = badge) do
  #   Map.put(badge, :badged, badge.badged ++ [Time.timestamp()])
  # end

  defp update_badged(currently_badged, badged_id) do
    case Map.has_key?(currently_badged, badged_id) do
      false -> Map.put(currently_badged, badged_id, [Time.timestamp()])
      true -> Map.update!(currently_badged, badged_id, &(&1 ++ [Time.timestamp()]))
    end
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
  @impl true
  def init(%Badge{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, :badge]}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(%{keys: [:badged], data: %{id: badged_id}}, _from, state) do
    # IO.inspect(state, label: "badge - current state")
    # new_state = Map.update!(state, :badged, &(&1 ++ [{badged_id, Time.timestamp()}]))
    # IO.inspect(new_state, label: "badge - new state")

    # updated_badge = state.badged
    # |> Map.has_key?(badged_id)
    # |> Enum.find({badged_id, Time.timestamp()}, fn {id, _badged_list} -> id == badged_id end)
    # |> IO.inspect(label: "found #{badged_id}")
    # |> add_badged()

    # case Map.has_key?(state.badged, badged_id) do
    #   false -> new_badged = Map.put(state.badged, badged_id, [Time.timestamp()])
    #   true -> new_badged = Map.update!(state.badged, badged_id, &(&1 ++ [Time.timestamp()]))
    # end

    new_state = state
    |> Map.put(:badged, update_badged(state.badged, badged_id))

    {:reply, new_state, new_state}
  end
end

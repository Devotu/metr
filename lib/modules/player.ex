defmodule Metr.Modules.Player do
  defstruct id: "", name: "", decks: [], results: [], matches: [], time: 0, tags: []

  use GenServer

  alias Metr.Modules.State
  alias Metr.Modules.Stately
  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Input.PlayerInput
  alias Metr.Util
  alias Metr.Time

  @atom :player

  def feed(
    %Event{
      id: _event_id,
      keys: [:create, @atom],
      data: %{id: id, input: _input}
      } = event,
    repp
  ) do

    State.create(id, @atom, event, repp)
  end

  def feed(
        %Event{
          keys: [:deck, :created, _orepp],
          data: %{out: deck_id}
        } = event,
        repp
      ) do

    deck = State.read(deck_id, :deck)

    [
      State.update(deck.player, @atom, event)
      |> Event.message_to_event([@atom, :altered, repp])
    ]
  end

  def feed(
        %Event{
          id: _event_id,
          keys: [:result, :created, _orepp],
          data: %{out: result_id}
        } = event,
        repp
      ) do

    result = State.read(result_id, :result)

    [
      State.update(result.player_id, @atom, event)
      |> Event.message_to_event([@atom, :altered, repp])
    ]
  end

  def feed(
      %Event{
        keys: [:match, :created, _orepp],
        data: %{out: match_id}
      } = event,
      repp
    ) do

  match = State.read(match_id, :match)

  [
    State.update(match.player_one, @atom, event)
    |> Event.message_to_event([@atom, :altered, repp]),
    State.update(match.player_two, @atom, event)
    |> Event.message_to_event([@atom, :altered, repp])
  ]
  end

  # # def feed(
  # #       %Event{
  # #         id: _event_id,
  # #         keys: [:game, :created, _orepp] = keys,
  # #         data: %{result_ids: result_ids}
  # #       } = event,
  # #       repp
  # #     ) do
  # #   player_result_ids =
  # #     result_ids
  # #     |> Enum.map(fn result_id -> Result.read(result_id) end)
  # #     |> Enum.map(fn r -> {r.player_id, r.id} end)

  # #   # for each participant
  # #   # call update
  # #   Enum.reduce(
  # #     player_result_ids,
  # #     [],
  # #     fn {id, result_id}, acc ->
  # #       acc ++
  # #         [
  # #           Stately.update(id, @atom, keys, %{id: result_id, player_id: id}, event)
  # #           |> Stately.out_to_event(@atom, [:altered, repp])
  # #         ]
  # #     end
  # #   )
  # # end

  # def feed(
  #       %Event{
  #         id: _event_id,
  #         keys: [:match, :created, _orepp] = keys,
  #         data: %{id: match_id, player_ids: player_ids}
  #       } = event,
  #       repp
  #     ) do
  #   # for each participant
  #   # call update
  #   Enum.reduce(player_ids, [], fn id, acc ->
  #     acc ++
  #       [
  #         Stately.update(id, @atom, keys, %{id: match_id, player_id: id}, event)
  #         |> Stately.out_to_event(@atom, [:altered, repp])
  #       ]
  #   end)
  # end

  # def feed(%Event{id: _event_id, keys: [:read, @atom], data: %{player_id: id}}, repp) do
  #   player = read(id)
  #   [Event.new([@atom, :read, repp], %{out: player})]
  # end

  # def feed(%Event{id: _event_id, keys: [:read, :log, @atom], data: %{player_id: id}}, repp) do
  #   events = Data.read_log_by_id(id, @atom)
  #   [Event.new([@atom, :read, repp], %{out: events})]
  # end

  def feed(event, _orepp) do
    # IO.inspect event, label: " ---- #{@atom} passed event"
    []
  end

  ## module
  # def read(id) do
  #   Stately.read(id, @atom)
  # end

  # def exist?(id) do
  #   Stately.exist?(id, @atom)
  # end

  # def module_name() do
  #   @atom
  # end

  ## gen
  @impl true
  def init(%Event{} = event) do
    id = event.data.id
    input = event.data.input
    state = %Player{
      id: id,
      name: input.name,
      time: event.time
    }
    case Data.save_state_with_log(@atom, id, state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:ok, state}
    end
  end

  @impl true
  def init(%Player{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, @atom]}, _from, state) do
    {:reply, state, state}
  end

  # @impl true
  # def init(input) do
  #   {:ok, %{}}
  # end

  @impl true
  def handle_call(
        %Event{keys: [:deck, :created, _repp]} = event,
        _from,
        state
      ) do

    deck = Metr.read(event.data.out, :deck)

    new_state = Map.update!(state, :decks, &(&1 ++ [deck.id]))

    case Data.save_state_with_log(@atom, deck.player, state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:reply, "Deck #{deck.id} added to player #{deck.player}", new_state}
    end
  end

  @impl true
  def handle_call(
        %{keys: [:result, :created, _orepp]} = event,
        _from,
        state
      ) do

    result = Metr.read(event.data.out, :result)

    new_state = Map.update!(state, :results, &(&1 ++ [result.id]))

    case Data.save_state_with_log(@atom, result.player_id, state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:reply, "Result #{result.id} added to player #{result.player_id}", new_state}
    end
  end

  @impl true
  def handle_call(
        %{keys: [:match, :created, _orepp]} = event,
        _from,
        state
      ) do

    match = Metr.read(event.data.out, :match)

    new_state = Map.update!(state, :matches, &(&1 ++ [match.id]))

    case Data.save_state_with_log(@atom, state.id, state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:reply, "Match #{match.id} added to player #{state.id}", new_state}
    end
  end

  @impl true
  def handle_call(
        %Event{keys: [@atom, :tagged], data: %{id: id, tag: tag} = event},
        _from,
        state
      ) do

    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    case Data.save_state_with_log(@atom, id, state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, new_state}
    end
    {:reply, "Deck #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

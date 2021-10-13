defmodule Metr.Modules.Deck do
  defstruct id: "",
            name: "",
            player: nil,
            format: "",
            theme: "",
            black: false,
            white: false,
            red: false,
            green: false,
            blue: false,
            colorless: false,
            results: [],
            matches: [],
            rank: nil,
            price: nil,
            time: 0,
            active: true,
            tags: []

  @formats [
    "block",
    "commander",
    "draft",
    "modern",
    "mixblock",
    "minimander",
    "pauper",
    "premodern",
    "sealed",
    "singleton",
    "standard",
    "threecard",
    "quirk"
  ]

  use GenServer

  alias Metr.Event
  alias Metr.Data
  alias Metr.Modules.State
  alias Metr.Modules.Deck
  alias Metr.Rank
  alias Metr.Modules.Input.DeckInput

  @atom :deck

  def feed(
    %Event{
      keys: [:create, @atom],
      data: %{id: id, input: _input}
      } = event,
    repp
  ) do

    State.create(id, @atom, event, repp)
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
    State.update(result.deck_id, @atom, event)
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
    State.update(match.deck_one, @atom, event)
    |> Event.message_to_event([@atom, :altered, repp]),
    State.update(match.deck_two, @atom, event)
    |> Event.message_to_event([@atom, :altered, repp])
  ]
  end

  def feed(%Event{id: _event_id, keys: [:list, :result], data: %{by: @atom, id: id}}, repp) do
    deck = State.read(id, @atom)
    [Event.new([:result, :list, repp], %{out: deck.results})]
  end

  def feed(
        %Event{
          keys: [:toggle, @atom, :active],
          data: %{id: id}
        } = event,
        repp
      ) do

    State.update(id, @atom, event)
    |> Event.message_to_event([@atom, :altered, repp])
  end

  def feed(
        %Event{keys: [:alter, :rank]} = event,
        repp
      ) do
    # call update
    [
      State.update(event.data.id, @atom, event)
      |> Event.message_to_event([@atom, :altered, repp])
    ]
  end

  def feed(%Event{keys: [:list, :format]}, repp) do
    [Event.new([:format, :list, repp], %{out: @formats})]
  end

  def feed(event, _orepp) do
    []
  end

  defp verify_new_deck_input(%DeckInput{} = data) do
    case {verify_name(data.name), verify_player(data.player_id), verify_format(data.format)} do
      {{:error, e}, _, _} -> {:error, e}
      {_, {:error, e}, _} -> {:error, e}
      {_, _, {:error, e}} -> {:error, e}
      _ -> {:ok}
    end
  end

  defp verify_name(nil), do: {:error, "a legal name must be assigned"}
  defp verify_name(name) when is_bitstring(name) do
    case name do
      "" -> {:error, "name cannot be blank"}
      _ -> {:ok}
    end
  end

  defp verify_player(nil), do: {:error, "a owner (player) must be assigned"}
  defp verify_player(id) do
    case State.exist?(id, :player) do
      true -> {:ok}
      false -> {:error, "player #{id} not found"}
    end
  end

  defp verify_format(format) do
    case Enum.member?(@formats, format) do
      true -> {:ok}
      false -> {:error, "format #{format} not vaild"}
    end
  end

  defp find_original_rank(%Event{data: %{rank: rank}}), do: Rank.uniform_rank(rank)
  defp find_original_rank(_), do: nil

  defp recalculate_rank(state, base_rank) do
    rank =
      state.results
      |> Enum.map(fn game_id -> Metr.read(game_id, :game) end)
      |> Enum.filter(fn g -> g.ranking end)
      |> Enum.reduce([], fn g, acc -> acc ++ g.results end)
      |> Enum.filter(fn p -> state.id == p.deck_id end)
      |> Enum.reduce(base_rank, fn p, acc -> Rank.apply_change(acc, Rank.find_change(p)) end)

    Map.put(state, :rank, rank)
  end


  defp from_input(%DeckInput{} = data, id, created_time) do
    %Deck{
      id: id,
      name: data.name,
      player: data.player_id,
      format: data.format,
      theme: data.theme,
      black: data.black,
      white: data.white,
      red: data.red,
      green: data.green,
      blue: data.blue,
      colorless: data.colorless,
      rank: nil,
      price: data.price,
      time: created_time
    }
  end

  @impl true
  def init(%Event{} = event) do
    id = event.data.id
    input = event.data.input

    case verify_new_deck_input(input) do
      {:error, e} ->
        {:stop, e}
      {:ok} ->
        state = from_input(input, id, event.time)
        case Data.save_state_with_log(@atom, id, state, event) do
          {:error, e} -> {:stop, e}
          _ ->
            {:ok, state}
        end
    end
  end

  @impl true
  def init(%Deck{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, @atom]}, _from, state) do
    # Reply
    {:reply, state, state}
  end

  @impl true
  def handle_call(
        %{keys: [:result, :created, _orepp]} = event,
        _from,
        state
      ) do

    result = Metr.read(event.data.out, :result)
    new_state = Map.update!(state, :results, &(&1 ++ [result.id]))

    case Data.save_state_with_log(@atom, state.id, new_state, event) do
      {:error, e} ->
        {:stop, e}
      _ ->
        {:reply, "Result #{result.id} added to deck #{state.id}", new_state}
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
        {:reply, "Match #{match.id} added to deck #{state.id}", new_state}
    end
  end

  @impl true
  def handle_call(
        %Event{keys: [:alter, :rank], data: %{id: id, change: change}} = event,
        _from,
        state
      ) do
    new_state = Map.update!(state, :rank, fn rank -> Rank.apply_change(rank, change) end)
    case Data.save_state_with_log(@atom, id, new_state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, new_state}
    end
    {:reply, "Deck #{id} rank altered to #{Kernel.inspect(new_state.rank)}", new_state}
  end

  @impl true
  def handle_call(
        %Event{keys: [:toggle, @atom, :active], data: %{id: id} = event},
        _from,
        state
      ) do

    new_state = Map.update!(state, :active, fn active -> not active end)
    case Data.save_state_with_log(@atom, id, new_state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, new_state}
    end
    {:reply, "Deck #{id} active altered to #{Kernel.inspect(new_state.active)}", new_state}
  end

  @impl true
  def handle_call(
        %Event{keys: [@atom, :tagged], data: %{id: id, tag: tag} = event},
        _from,
        state
      ) do

    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    case Data.save_state_with_log(@atom, id, new_state, event) do
      {:error, e} -> {:stop, e}
      _ -> {:ok, new_state}
    end
    {:reply, "Deck #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

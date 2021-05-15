defmodule Metr.Modules.Deck do
  defstruct id: "",
            name: "",
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
  alias Metr.Id
  alias Metr.Data
  alias Metr.Modules.Stately
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Player
  alias Metr.Rank
  alias Metr.Modules.Result
  alias Metr.Modules.Input.DeckInput
  alias Metr.Util

  @atom :deck

  ## feed
  def feed(%Event{keys: [:create, @atom], data: %DeckInput{} = data} = event, repp) do
    case verify_new_deck_input(data) do
      {:error, cause} ->
        # Return
        [Event.new([@atom, :error, repp], %{cause: cause, data: data})]

      {:ok} ->
        id = Id.hrid(data.name)
        process_name = Data.genserver_id(@atom, id)
        # Start genserver
        case GenServer.start(Metr.Modules.Deck, {id, data, event}, name: process_name) do
          {:ok, _pid} ->
            [Event.new([@atom, :created, nil], %{id: id, player_id: data.player_id}),
            Event.new([@atom, :created, repp], %{out: id})]

          {:error, cause} ->
            [Event.new([@atom, :error, repp], %{cause: cause})]
        end
    end
  end

  def feed(
        %Event{
          keys: [:game, :created, _orepp] = keys,
          data: %{result_ids: result_ids}
        } = event,
        repp
      ) do
    deck_result_ids =
      result_ids
      |> Enum.map(fn result_id -> Result.read(result_id) end)
      |> Enum.map(fn r -> {r.deck_id, r.id} end)

    # for each participant
    # call update
    Enum.reduce(
      deck_result_ids,
      [],
      fn {id, result_id}, acc ->
        acc ++
          [
            Stately.update(id, @atom, keys, %{id: result_id, deck_id: id}, event)
            |> Stately.out_to_event(@atom, [:altered, repp])
          ]
      end
    )
  end

  def feed(
        %Event{
          keys: [:game, :deleted, _orepp] = keys,
          data: %{results: result_ids}
        } = event,
        repp
      ) do
    # for each deck find connections to this game
    deck_result_ids =
      Data.list_ids(@atom)
      |> Enum.map(fn id -> read(id) end)
      |> Enum.filter(fn d -> Util.has_member?(d.results, result_ids) end)
      |> Enum.map(fn d -> {d.id, Util.find_first_common_member(d.results, result_ids)} end)

    # call update
    Enum.reduce(deck_result_ids, [], fn {id, result_id}, acc ->
      acc ++
        [
          Stately.update(id, @atom, keys, %{id: result_id, deck_id: id}, event)
          |> Stately.out_to_event(@atom, [:altered, repp])
        ]
    end)
  end

  def feed(%Event{keys: [:read, :log, @atom], data: %{deck_id: id}}, repp) do
    events = Data.read_log_by_id(id, @atom)
    [Event.new([@atom, :read, repp], %{out: events})]
  end

  def feed(
        %Event{
          keys: [:match, :created, _orepp] = keys,
          data: %{id: match_id, deck_ids: deck_ids}
        } = event,
        repp
      ) do
    # for each participant
    # call update
    Enum.reduce(deck_ids, [], fn id, acc ->
      acc ++
        [
          Stately.update(id, @atom, keys, %{id: match_id, deck_id: id}, event)
          |> Stately.out_to_event(@atom, [:altered, repp])
        ]
    end)
  end

  def feed(
        %Event{
          keys: [:toggle, @atom, :active] = keys,
          data: %{deck_id: deck_id} = data
        } = event,
        repp
      ) do
    Stately.update(deck_id, @atom, keys, data, event)
    |> Stately.out_to_event(@atom, [:altered, repp])
  end

  def feed(%Event{keys: [:read, @atom], data: %{deck_id: id}}, repp) do
    deck = read(id)
    [Event.new([@atom, :read, repp], %{out: deck})]
  end

  def feed(%Event{keys: [:list, :game], data: %{deck_id: id}}, repp) do
    deck = read(id)

    games =
      deck.results
      |> Enum.map(fn rid -> Result.read(rid) end)
      |> Enum.map(fn r -> Game.read(r.game_id) end)

    [{Event.new([:game, :list, repp], %{out: games}), repp}]
  end

  def feed(%Event{keys: [:list, :result], data: %{deck_id: id}}, repp) do
    deck = read(id)
    [{Event.new([:list, :result], %{ids: deck.results}), repp}]
  end

  def feed(
        %Event{keys: [:alter, :rank] = keys, data: %{deck_id: id, change: change}} = event,
        repp
      ) do
    # call update
    [
      Stately.update(id, @atom, keys, %{id: id, change: change}, event)
      |> Stately.out_to_event(@atom, [:altered, repp])
    ]
  end

  def feed(%Event{keys: [:list, :format]}, repp) do
    [Event.new([:format, :list, repp], %{out: @formats})]
  end

  def feed(_event, _orepp) do
    []
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
  defp verify_player(player_id) do
    case Player.exist?(player_id) do
      true -> {:ok}
      false -> {:error, "player #{player_id} not found"}
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

  ## gen
  @impl true
  def init({id, %DeckInput{} = data, event}) do
    state = from_input(data, id, event.time)
    :ok = Data.save_state_with_log(@atom, id, state, event)
    {:ok, state}
  end

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
        %{keys: [:game, :created, _orepp], data: %{id: result_id, deck_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :results, &(&1 ++ [result_id]))
    :ok = Data.save_state_with_log(@atom, id, new_state, event)
    {:reply, "Result #{result_id} added to deck #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:match, :created, _orepp], data: %{id: match_id, deck_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :matches, &(&1 ++ [match_id]))
    :ok = Data.save_state_with_log(@atom, id, new_state, event)
    {:reply, "Match #{match_id} added to deck #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:game, :deleted, _orepp], data: %{deck_id: id, id: result_id}, event: event},
        _from,
        state
      ) do
    original_rank =
      Data.read_log_by_id(id, @atom)
      |> Enum.filter(fn e -> e.keys == [:create, @atom] end)
      |> List.first()
      |> find_original_rank()

    new_state =
      state
      |> Map.update!(:results, fn results -> List.delete(results, result_id) end)
      |> recalculate_rank(original_rank)

    :ok = Data.save_state_with_log(@atom, id, new_state, event)
    {:reply, "Result #{result_id} removed from deck #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:alter, :rank], data: %{id: id, change: change}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :rank, fn rank -> Rank.apply_change(rank, change) end)
    :ok = Data.save_state_with_log(@atom, id, new_state, event)
    {:reply, "Deck #{id} rank altered to #{Kernel.inspect(new_state.rank)}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:toggle, @atom, :active], data: %{deck_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :active, fn active -> not active end)
    :ok = Data.save_state_with_log(@atom, id, new_state, event)
    {:reply, "Deck #{id} active altered to #{Kernel.inspect(new_state.active)}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:tagged], data: %{id: id, tag: tag}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    :ok = Data.save_state_with_log(@atom, id, new_state, event)
    {:reply, "Deck #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

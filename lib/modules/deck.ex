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
            tags: [],
            badges: %{}

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
  alias Metr.Util
  alias Metr.Time

  @name __ENV__.module |> Stately.module_to_name()

  ## feed
  def feed(%Event{keys: [:create, :deck], data: data} = event, repp) do
    case verify_creation_data(data) do
      {:error, reason} ->
        # Return
        [Event.new([:deck, :error, repp], %{cause: reason, data: data})]

      {:ok} ->
        id = Id.hrid(data.name)
        process_name = Data.genserver_id(__ENV__.module, id)
        # Start genserver
        case GenServer.start(Metr.Modules.Deck, {id, data, event}, name: process_name) do
          {:ok, _pid} ->
            [Event.new([:deck, :created, repp], %{id: id, player_id: data.player_id})]

          {:error, error} ->
            [Event.new([:deck, :not, :created, repp], %{errors: [error]})]
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
            Stately.update(id, @name, keys, %{id: result_id, deck_id: id}, event)
            |> Stately.out_to_event(@name, [:altered, repp])
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
      Data.list_ids(__ENV__.module)
      |> Enum.map(fn id -> read(id) end)
      |> Enum.filter(fn d -> Util.has_member?(d.results, result_ids) end)
      |> Enum.map(fn d -> {d.id, Util.find_first_common_member(d.results, result_ids)} end)

    # call update
    Enum.reduce(deck_result_ids, [], fn {id, result_id}, acc ->
      acc ++
        [
          Stately.update(id, @name, keys, %{id: result_id, deck_id: id}, event)
          |> Stately.out_to_event(@name, [:altered, repp])
        ]
    end)
  end

  def feed(%Event{keys: [:read, :log, :deck], data: %{deck_id: id}}, repp) do
    events = Data.read_log_by_id("Deck", id)
    [Event.new([:deck, :log, :read, repp], %{out: events})]
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
          Stately.update(id, @name, keys, %{id: match_id, deck_id: id}, event)
          |> Stately.out_to_event(@name, [:altered, repp])
        ]
    end)
  end

  def feed(
        %Event{
          keys: [:toggle, :deck, :active] = keys,
          data: %{deck_id: deck_id} = data
        } = event,
        repp
      ) do
    Stately.update(deck_id, @name, keys, data, event)
    |> Stately.out_to_event(@name, [:altered, repp])
  end

  def feed(%Event{keys: [:read, :deck], data: %{deck_id: id}}, repp) do
    deck = read(id)
    [Event.new([:deck, :read, repp], %{out: deck})]
  end

  def feed(%Event{keys: [:list, :game], data: %{deck_id: id}}, repp) do
    deck = read(id)

    games =
      deck.results
      |> Enum.map(fn rid -> Result.read(rid) end)
      |> Enum.map(fn r -> Game.read(r.game_id) end)

    [{Event.new([:games, repp], %{games: games}), repp}]
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
      Stately.update(id, @name, keys, %{id: id, change: change}, event)
      |> Stately.out_to_event(@name, [:altered, repp])
    ]
  end

  def feed(%Event{keys: [:list, :format]}, repp) do
    [Event.new([:formats, repp], %{formats: @formats})]
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

  defp verify_creation_data(%{name: name, player_id: player_id} = data) do
    {:ok}
    |> verify_name(name)
    |> verify_player(player_id)
    |> verify_input_content(data)
  end

  defp verify_creation_data(%{player_id: _player_id}), do: {:error, "missing name parameter"}
  defp verify_creation_data(%{name: _name}), do: {:error, "missing player_id parameter"}

  defp verify_name({:error, _cause} = error, _id), do: error

  defp verify_name({:ok}, name) when is_bitstring(name) do
    case name do
      nil -> {:error, "no name"}
      "" -> {:error, "name cannot be blank"}
      _ -> {:ok}
    end
  end

  defp verify_player({:error, _cause} = error, _id), do: error

  defp verify_player({:ok}, player_id) do
    case Player.exist?(player_id) do
      true -> {:ok}
      false -> {:error, "player #{player_id} not found"}
    end
  end

  defp verify_input_content({:error, _error} = e, _data), do: e

  defp verify_input_content({:ok}, data) do
    valid_input_data = %{
      name: "",
      player_id: "",
      format: "",
      theme: "",
      rank: 0,
      advantage: 0,
      price: 0,
      black: false,
      white: false,
      red: true,
      green: false,
      blue: true,
      colorless: false,
      colors: %{},
      parts: []
    }

    case Enum.empty?(Map.keys(data) -- Map.keys(valid_input_data)) do
      true -> {:ok}
      false -> {:error, "excess params given"}
    end
  end

  defp build_state(id, %{name: name} = data) do
    %Deck{id: id, name: name, time: Time.timestamp()}
    |> apply_colors(data)
    |> apply_format(data)
    |> apply_rank(data)
    |> stamp_deck()
  end

  defp apply_colors({:error, _error} = e, _data), do: {e}

  defp apply_colors(%Deck{} = deck, data) when is_map(data) do
    case color_data_type(data) do
      :list ->
        Enum.reduce(data.colors, deck, fn c, d -> apply_color(c, d) end)

      :bool ->
        Map.merge(deck, data)

      _ ->
        deck
    end
  end

  defp color_data_type(%{colors: _colors}), do: :list

  defp color_data_type(%{
         black: _b,
         white: _w,
         red: _r,
         green: _g,
         blue: _bl,
         colorless: _c
       }),
       do: :bool

  defp color_data_type(_), do: :none

  defp apply_color(color, %Deck{} = deck) when is_atom(color) do
    Map.put(deck, color, true)
  end

  defp apply_format({:error, _error} = e, _data), do: e

  defp apply_format(%Deck{} = deck, data) when is_map(data) do
    case Map.has_key?(data, :format) do
      true ->
        apply_format(deck, data.format)

      false ->
        deck
    end
  end

  defp apply_format(deck, format_descriptor) when is_bitstring(format_descriptor) do
    case String.downcase(format_descriptor) do
      f when f in @formats -> Map.put(deck, :format, format_descriptor)
      _ -> {:error, :invalid_format}
    end
  end

  defp apply_rank({:error, _error} = e, _data), do: e

  defp apply_rank(%Deck{} = deck, data) do
    case Map.has_key?(data, :rank) and is_tuple(data.rank) do
      true ->
        Map.update!(deck, :rank, fn _r -> Rank.uniform_rank(data.rank) end)

      false ->
        deck
    end
  end

  defp stamp_deck({:error, _error} = e), do: e

  defp stamp_deck(data) when is_map(data) do
    Map.take(data, Map.keys(%Deck{}))
  end

  defp find_original_rank(%Event{data: %{rank: rank}}), do: Rank.uniform_rank(rank)
  defp find_original_rank(_), do: nil

  defp recalculate_rank(state, base_rank) do
    rank =
      state.results
      |> Enum.map(fn game_id -> Metr.read_game(game_id) end)
      |> Enum.filter(fn g -> g.ranking end)
      |> Enum.reduce([], fn g, acc -> acc ++ g.results end)
      |> Enum.filter(fn p -> state.id == p.deck_id end)
      |> Enum.reduce(base_rank, fn p, acc -> Rank.apply_change(acc, Rank.find_change(p)) end)

    Map.put(state, :rank, rank)
  end

  ## gen
  @impl true
  def init({id, data, event}) do
    case build_state(id, data) do
      {:error, error} ->
        {:stop, error}

      %Deck{} = state ->
        :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
        {:ok, state}
    end
  end

  def init(%Deck{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, :deck]}, _from, state) do
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
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "Result #{result_id} added to deck #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:match, :created, _orepp], data: %{id: match_id, deck_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :matches, &(&1 ++ [match_id]))
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "Match #{match_id} added to deck #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:game, :deleted, _orepp], data: %{deck_id: id, id: result_id}, event: event},
        _from,
        state
      ) do
    original_rank =
      Data.read_log_by_id("Deck", id)
      |> Enum.filter(fn e -> e.keys == [:create, :deck] end)
      |> List.first()
      |> find_original_rank()

    new_state =
      state
      |> Map.update!(:results, fn results -> List.delete(results, result_id) end)
      |> recalculate_rank(original_rank)

    :ok = Data.save_state_with_log(__ENV__.module, id, new_state, event)
    {:reply, "Result #{result_id} removed from deck #{id}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:alter, :rank], data: %{id: id, change: change}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :rank, fn rank -> Rank.apply_change(rank, change) end)
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "Deck #{id} rank altered to #{Kernel.inspect(new_state.rank)}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:toggle, :deck, :active], data: %{deck_id: id}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :active, fn active -> not active end)
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "Deck #{id} active altered to #{Kernel.inspect(new_state.active)}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:tagged], data: %{id: id, tag: tag}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "Deck #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end

  @impl true
  def handle_call(
        %{keys: [:badged], data: %{id: id, badge: badge}, event: event},
        _from,
        state
      ) do
    new_state = Map.put(state, :badges, Util.stamp_ts_map(state.badges, badge))
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "#{@name} #{id} badges altered to #{Kernel.inspect(new_state.badges)}", new_state}
  end
end

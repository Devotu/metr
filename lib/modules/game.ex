defmodule Metr.Modules.Game do
  defstruct id: "", time: 0, results: [], match: nil, tags: [], turns: nil

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.Stately
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.ResultInput

  @name __ENV__.module |> Stately.module_to_name()

  ## feed
  def feed(%Event{id: _event_id, keys: [:create, :game], data: %GameInput{} = data} = event, repp) do
    case verify_input_data(data) do
      {:error, error} ->
        [Event.new([:game, :error, repp], %{cause: error, data: data})]

      {:ok} ->
        id = Id.guid()
        process_name = Data.genserver_id(__ENV__.module, id)
        result_inputs = convert_to_result_inputs(data, id)

        result_ids =
          result_inputs
          |> Enum.map(fn r -> Result.create(r, event) end)
          |> Enum.map(fn {:ok, result_id} -> result_id end)


        data = Map.put(data, :results, result_ids)

        case GenServer.start(Metr.Modules.Game, {id, data, event},
               name: process_name
             ) do

          {:ok, _pid} ->
            match_id = Map.get(data, :match, nil)
            [
              Event.new([:game, :created, repp], %{
                id: id,
                result_ids: result_ids,
                ranking: is_ranked?(data),
                match_id: match_id
              }),
              Event.new([:game, :created, repp], %{
                out: id
              })
            ]

          {:error, cause} ->
            [Event.new([:game, :error, repp], %{cause: cause})]

          _ ->
            [Event.new([:game, :error, repp], %{cause: "Could not save game state"})]
        end
    end
  end

  def feed(%Event{id: _event_id, keys: [:read, :game], data: %{game_id: id}}, repp) do
    game = read(id)
    [Event.new([:game, :read, repp], %{out: game})]
  end

  def feed(%Event{id: _event_id, keys: [:read, :log, :game], data: %{game_id: id}}, repp) do
    events = Data.read_log_by_id(id, "Game")
    [Event.new([:game, :read, repp], %{out: events})]
  end

  def feed(%Event{id: _event_id, keys: [:list, :game], data: %{ids: ids}}, repp)
      when is_list(ids) do
    games = Enum.map(ids, &read/1)
    [Event.new([:games, repp], %{games: games})]
  end

  def feed(%Event{id: _event_id, keys: [:list, :game], data: %{limit: limit}}, repp)
      when is_number(limit) do
    games =
      Data.list_ids(__ENV__.module)
      |> Enum.map(&read/1)
      |> Enum.sort(&(&1.time < &2.time))
      |> Enum.take(limit)

    [Event.new([:games, repp], %{games: games})]
  end

  def feed(%Event{id: _event_id, keys: [:list, :result], data: %{game_id: id}}, repp) do
    game = read(id)
    [{Event.new([:list, :result], %{ids: game.results}), repp}]
  end

  def feed(%Event{id: _event_id, keys: [:delete, :game], data: %{game_id: game_id}}, repp) do
    delete_conclusion =
      game_id
      |> read()
      |> delete_game_results()
      |> delete_game()

    case delete_conclusion do
      %Game{} = game ->
        [Event.new([:game, :deleted, nil], %{id: game_id, results: game.results}),
        Event.new([:game, :deleted, repp], %{out: game_id})]

      {:error, cause} ->
        [Event.new([:game, :error, repp], %{cause: cause})]
    end
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

  ## private
  defp convert_to_result_inputs(%GameInput{} = data, game_id) do
    [to_result_input(data.player_one, data.deck_one, game_id, is_winner(data.winner, 1), data.power_one, data.fun_one),
    to_result_input(data.player_two, data.deck_two, game_id, is_winner(data.winner, 2), data.power_two, data.fun_two)]
  end

  defp to_result_input(player_id, deck_id, game_id, place, power, fun) do
    %ResultInput{
      player_id: player_id,
      deck_id: deck_id,
      game_id: game_id,
      place: place,
      power: power,
      fun: fun
    }
  end

  @spec is_winner(integer, integer) :: integer
  defp is_winner(winner, part) do
    case winner == part do
      true -> 1
      false -> 2
    end
  end

  ## Input verification
  defp verify_input_data(%GameInput{} = data) do
    p1 = verify_part(data.player_one, data.deck_one, data.power_one, data.fun_one)
    p2 = verify_part(data.player_two, data.deck_two, data.power_two, data.fun_two)
    w = verify_winner(data.winner)

    case [p1, p2, w] do
      [{:error, e}, _, _] -> {:error, e}
      [_, {:error, e}, _] -> {:error, e}
      [_, _, {:error, e}] -> {:error, e}
      _ -> {:ok}
    end
  end

  defp verify_part(player_id, deck_id, power, fun) do
    p = verify_player(player_id)
    d = verify_deck(deck_id)
    po = verify_power(power)
    f = verify_fun(fun)

    case [p, d, po, f] do
      [{:error, e}, _, _, _] -> {:error, e}
      [_, {:error, e}, _, _] -> {:error, e}
      [_, _, {:error, e}, _] -> {:error, e}
      [_, _, _, {:error, e}] -> {:error, e}
      _ -> {:ok}
    end
  end

  defp verify_player(player_id) do
    case Player.exist?(player_id) do
      true -> {:ok}
      false -> {:error, "player #{player_id} not found"}
    end
  end

  defp verify_deck(deck_id) do
    case Deck.exist?(deck_id) do
      true -> {:ok}
      false -> {:error, "deck #{deck_id} not found"}
    end
  end

  defp verify_winner(0), do: {:ok}
  defp verify_winner(1), do: {:ok}
  defp verify_winner(2), do: {:ok}
  defp verify_winner(nil), do: {:error, "winner must be set"}
  defp verify_winner(winner) when not is_number(winner), do: {:error, "winner must be a number"}
  defp verify_winner(winner) when winner > 2 or winner < 0, do: {:error, "winner must be a number in [0,1,2]"}
  defp verify_winner(_), do: {:ok}

  defp verify_power(nil), do: {:ok}
  defp verify_power(power) when not is_number(power), do: {:error, "invalid power input - power #{Kernel.inspect(power)} not a number"}
  defp verify_power(power) when power > 2 or power < -2, do: {:error, "invalid power input - power #{power} is not in range"}
  defp verify_power(_data), do: {:ok}

  defp verify_fun(nil), do: {:ok}
  defp verify_fun(fun) when not is_number(fun), do: {:error, "invalid fun input - fun #{Kernel.inspect(fun)} is not a number"}
  defp verify_fun(fun) when fun > 2 or fun < -2, do: {:error, "invalid fun input - fun #{fun} is not in range"}
  defp verify_fun(_), do: {:ok}

  ## Internals
  defp is_ranked?(%{ranked: ranked}) when is_boolean(ranked), do: ranked
  defp is_ranked?(_), do: false

  defp delete_game_results({:error, cause}), do: {:error, cause}

  defp delete_game_results(%Game{} = game) do
    all_deleted? =
      game.results
      |> Enum.map(fn rid -> Result.delete(rid) end)
      |> Enum.all?(fn x -> x == :ok end)

    case all_deleted? do
      true -> game
      false -> {:error, "Not all results deleted"}
    end
  end

  defp delete_game({:error, cause}), do: {:error, cause}

  defp delete_game(%Game{} = game) do
    case Data.wipe_state(game.id, __ENV__.module) do
      :ok -> game
      _ -> {:error, "Could not delete game state"}
    end
  end

  defp from_input(%GameInput{} = data, id, created_time) do
    %Game{
      id: id,
      time: created_time,
      match: data.match,
      turns: data.turns,
      tags: data.tags,
      results: data.results
    }
  end

  ## gen
  @impl true
  def init({id, %GameInput{} = data, event}) do
    state = from_input(data, id, event.time)
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:ok, state}
  end

  def init(%Game{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, :game]}, _from, state) do
    # Reply
    {:reply, state, state}
  end

  @impl true
  def handle_call(
        %{keys: [:tagged], data: %{id: id, tag: tag}, event: event},
        _from,
        state
      ) do
    new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
    :ok = Data.save_state_with_log(__ENV__.module, id, state, event)
    {:reply, "#{@name} #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

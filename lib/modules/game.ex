defmodule Metr.Modules.Game do
  defstruct id: "", time: 0, results: [], match: nil, tags: [], turns: nil

  use GenServer

  alias Metr.Event
  alias Metr.Id
  alias Metr.Data
  alias Metr.Router
  alias Metr.Modules.Deck
  alias Metr.Modules.Game
  alias Metr.Modules.Player
  alias Metr.Modules.Result
  alias Metr.Modules.State
  alias Metr.Modules.Stately
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.ResultInput

  @atom :game

  ## feed
  # def feed(%Event{id: _event_id, keys: [:create, @atom], data: %GameInput{} = data} = event, repp) do
  #   case verify_input_data(data) do
  #     {:error, error} ->
  #       [Event.new([@atom, :error, repp], %{cause: error, data: data})]

  #     {:ok} ->
  #       id = Id.guid()
  #       process_name = Data.genserver_id(@atom, id)
  #       result_inputs = convert_to_result_inputs(data, id)

  #       result_ids =
  #         result_inputs
  #         |> Enum.map(fn r -> Result.create(r, event) end)
  #         |> Enum.map(fn {:ok, result_id} -> result_id end)


  #       data = Map.put(data, :results, result_ids)

  #       case GenServer.start(Metr.Modules.Game, {id, data, event},
  #              name: process_name
  #            ) do

  #         {:ok, _pid} ->
  #           match_id = Map.get(data, :match, nil)
  #           [
  #             Event.new([@atom, :created, nil], %{
  #               id: id,
  #               result_ids: result_ids,
  #               ranking: is_ranked?(data),
  #               match_id: match_id
  #             }),
  #             Event.new([@atom, :created, repp], %{
  #               out: id
  #             })
  #           ]

  #         {:error, cause} ->
  #           [Event.new([@atom, :error, repp], %{cause: cause})]

  #         _ ->
  #           [Event.new([@atom, :error, repp], %{cause: "Could not save game state"})]
  #       end
  #   end
  # end

  # def feed(%Event{id: _event_id, keys: [:read, @atom], data: %{game_id: id}}, repp) do
  #   game = read(id)
  #   [Event.new([@atom, :read, repp], %{out: game})]
  # end

  # def feed(%Event{id: _event_id, keys: [:read, :log, @atom], data: %{game_id: id}}, repp) do
  #   events = Data.read_log_by_id(id, @atom)
  #   [Event.new([@atom, :read, repp], %{out: events})]
  # end

  # def feed(%Event{id: _event_id, keys: [:list, @atom], data: %{ids: ids}}, repp)
  #     when is_list(ids) do
  #   games = Enum.map(ids, &read/1)
  #   [Event.new([@atom, :list, repp], %{out: games})]
  # end

  def feed(%Event{id: _event_id, keys: [:list, @atom], data: %{by: :deck, id: deck_id}}, repp) do
    games = deck_id
    |> State.read(:deck)
    |> then(fn deck -> deck.results end)
    |> Enum.map(fn rid -> State.read(rid, :result) end)
    |> Enum.map(fn r -> State.read(r.game_id, :game) end)

    [Event.new([@atom, :list, repp], %{out: games})]
  end

  def feed(%Event{id: _event_id, keys: [:list, @atom], data: %{limit: limit}}, repp)
      when is_number(limit) do
    games =
      Data.list_ids(@atom)
      |> Enum.map(fn id -> State.read(id, @atom) end)
      |> Enum.sort(&(&1.time < &2.time))
      |> Enum.take(limit)

    [Event.new([@atom, :list, repp], %{out: games})]
  end


  def feed(
    %Event{
      keys: [:create, @atom],
      data: %{id: id, input: _input}
      } = event,
    repp
  ) do

    State.create(id, @atom, event, repp)
  end

  def feed(%Event{id: _event_id, keys: [:list, :result], data: %{by: @atom, id: id}}, repp) do
    game = State.read(id, @atom)
    [Event.new([:result, :list, repp], %{out: game.results})]
  end

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

  ## private
  defp convert_to_result_inputs(%GameInput{} = data, game_id) do
    [to_result_input(data.player_one, data.deck_one, game_id, find_place(data.winner, 1), data.power_one, data.fun_one),
    to_result_input(data.player_two, data.deck_two, game_id, find_place(data.winner, 2), data.power_two, data.fun_two)]
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

  @spec find_place(integer, integer) :: integer
  defp find_place(0, _part), do: 0
  defp find_place(winner, part) do
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
    case State.exist?(player_id, :player) do
      true -> {:ok}
      false -> {:error, "player #{player_id} not found"}
    end
  end

  defp verify_deck(deck_id) do
    case State.exist?(deck_id, :deck) do
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


  # def feed(%Event{id: _event_id, keys: [:create, @atom], data: %GameInput{} = data} = event, repp) do
  #   case verify_input_data(data) do
  #     {:error, error} ->
  #       [Event.new([@atom, :error, repp], %{cause: error, data: data})]

  #     {:ok} ->
  #       id = Id.guid()
  #       process_name = Data.genserver_id(@atom, id)
  #       result_inputs = convert_to_result_inputs(data, id)

  #       result_ids =
  #         result_inputs
  #         |> Enum.map(fn r -> Result.create(r, event) end)
  #         |> Enum.map(fn {:ok, result_id} -> result_id end)


  #       data = Map.put(data, :results, result_ids)

  #       case GenServer.start(Metr.Modules.Game, {id, data, event},
  #              name: process_name
  #            ) do

  #         {:ok, _pid} ->
  #           match_id = Map.get(data, :match, nil)
  #           [
  #             Event.new([@atom, :created, nil], %{
  #               id: id,
  #               result_ids: result_ids,
  #               ranking: is_ranked?(data),
  #               match_id: match_id
  #             }),
  #             Event.new([@atom, :created, repp], %{
  #               out: id
  #             })
  #           ]

  #         {:error, cause} ->
  #           [Event.new([@atom, :error, repp], %{cause: cause})]

  #         _ ->
  #           [Event.new([@atom, :error, repp], %{cause: "Could not save game state"})]
  #       end
  #   end
  # end

  ## gen
  @impl true
  def init(%Event{} = event) do
    id = event.data.id
    input = event.data.input
    case verify_input_data(input) do
      {:error, e} ->
        {:stop, e}
      {:ok} ->
        [result_1_input, result_2_input] = convert_to_result_inputs(input, id)

        result_1_id = Id.guid()
        result_2_id = Id.guid()

        complete_input = Map.put(input, :results, [result_1_id, result_2_id])

        state = from_input(complete_input, id, event.time)
        case Data.save_state_with_log(@atom, id, state, event) do
          {:error, e} ->
            {:stop, e}
          _ ->
            Router.input([
              Event.new([:create, :result], %{id: result_1_id, input: result_1_input}),
              Event.new([:create, :result], %{id: result_2_id, input: result_2_input}),
            ])
            {:ok, state}
        end
    end
  end

  def init({id, %GameInput{} = data, event}) do
    case verify_input_data(data) do
      {:error, e} ->
        {:stop, e}
      {:ok} ->
        [result_1_input, result_2_input] = convert_to_result_inputs(data, id)

        result_1_id = Id.guid()
        result_2_id = Id.guid()

        data = Map.put(data, :results, [result_1_id, result_2_id])
        state = from_input(data, id, event.time)

        case Data.save_state_with_log(@atom, id, state, event) do
          {:error, e} ->
            {:stop, e}
          _ ->
            Router.input([
              Event.new([:create, :result], %{id: result_1_id, input: result_1_input}),
              Event.new([:create, :result], %{id: result_2_id, input: result_2_input}),
            ])

            {:ok, state}
        end
    end
  end

  def init(%Game{} = state) do
    {:ok, state}
  end

  @impl true
  def handle_call(%{keys: [:read, @atom]}, _from, state) do
    {:reply, state, state}
  end

  # @impl true
  # def handle_call(
  #       %{keys: [:tagged], data: %{id: id, tag: tag}, event: event},
  #       _from,
  #       state
  #     ) do
  #   new_state = Map.update!(state, :tags, &(&1 ++ [tag]))
  #   case Data.save_state_with_log(@atom, id, new_state, event) do
  #     {:error, e} -> {:stop, e}
  #     _ -> {:ok, state}
  #   end
  #   {:reply, "#{@atom} #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  # end



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
    {:reply, "Game #{id} tags altered to #{Kernel.inspect(new_state.tags)}", new_state}
  end
end

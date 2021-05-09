defmodule Metr do
  alias Metr.Event
  alias Metr.History
  alias Metr.Router
  alias Metr.Modules.Stately
  alias Metr.Modules.Input.GameInput

  ## api
  def list_players(), do: list(:player)

  def list_decks(), do: list(:deck)

  def list_results(), do: list(:result)

  def list_matches(), do: list(:match)

  def list_formats(), do: list(:format)

  def list_games(), do: list(:game)
  def list_games(game_ids) when is_list(game_ids), do: game_ids |> Enum.map(fn gid -> read_game(gid) end)
  def list_games(limit) when is_number(limit) do
    constraints = Map.put(%{}, :limit, limit)
    list(:game, constraints)
  end
  def list_games(type, id) when is_atom(type) do
    constraints = Map.put(%{}, Stately.module_id(type), id)
    list(:game, constraints)
  end

  def list_states(type, ids) when is_atom(type) do
    Enum.map(ids, fn id -> read(type, id) end)
  end

  def list_states(ids, type) when is_atom(type) do
    Enum.map(ids, fn id -> read(type, id) end)
  end

  def list_states(state_type, by_type, id) when is_atom(state_type) and is_atom(by_type) do
    constraints = Map.put(%{}, Stately.module_id(by_type), id)
    list(state_type, constraints)
  end

  def list_states(type) when is_bitstring(type) do
    type
    |> Stately.select_module_atom()
    |> list()
  end

  def read_player(id), do: read(:player, id)

  def read_deck(id), do: read(:deck, id)

  def read_game(id), do: read(:game, id)

  def read_match(id), do: read(:match, id)

  @spec read_entity_log(:deck | :game | :match | :player | :result, any) :: any
  def read_entity_log(type, id) when is_atom(type) do
    read_log(type, id)
  end

  def read_entity_log(type, id) when is_bitstring(type) do
    type
    |> Stately.select_module_atom()
    |> read_log(id)
  end

  def read_entity_history(id, type) when is_bitstring(type) do
    History.of_entity id, Stately.select_module_atom(type)
  end

  def read_input_log(limit) when is_number(limit) do
    read_log(limit)
  end

  def read_state(id, type) when is_atom(type) and is_bitstring(id), do: read(type, id)

  def read_state(type, id) when is_atom(type) and is_bitstring(id), do: read(type, id)

  def read_state(type, id) when is_bitstring(type) and is_bitstring(id) do
    type
    |> Stately.select_module_atom()
    |> read(id)
  end

  def read_state(_type, _id) do
    {:error, "Bad argument(s)"}
  end

  def create_game(%GameInput{} = input) do
    data = %{
      winner: input.winner,
      ranking: input.ranking,
      match: input.match,
      parts: [
        %{part: 1, details: %{deck_id: input.deck_one, player_id: input.player_one, power: input.power_one, fun: input.fun_one}},
        %{part: 2, details: %{deck_id: input.deck_two, player_id: input.player_two, power: input.power_two, fun: input.fun_two}},
      ],
      turns: input.turns
    }

    create(:game, data)
  end

  def create_game(%{
        :deck_1 => d1,
        :deck_2 => d2,
        :fun_1 => f1,
        :fun_2 => f2,
        :player_1 => p1,
        :player_2 => p2,
        :power_1 => s1,
        :power_2 => s2,
        :winner => w,
        ranking: r,
        match: m
      }) do
    data = %{
      winner: w,
      ranking: r,
      match: m,
      parts: [
        %{part: 1, details: %{deck_id: d1, player_id: p1, power: s1, fun: f1}},
        %{part: 2, details: %{deck_id: d2, player_id: p2, power: s2, fun: f2}}
      ],
      turns: nil
    }

    create_game(data)
  end

  # def create_game(%{balance: b} = game_data) do
  #   case parse_balance(b) do
  #     {:error, msg} ->
  #       {:error, msg}

  #     {pw1, pw2} ->
  #       Map.merge(@default_game, game_data)
  #       |> Map.put(:power_1, pw1)
  #       |> Map.put(:power_2, pw2)
  #       |> create_game()
  #   end
  # end

  # def create_game(
  #       %{
  #         :deck_1 => _d1,
  #         :deck_2 => _d2,
  #         :player_1 => _p1,
  #         :player_2 => _p2
  #       } = game_data
  #     )
  #     when is_map(game_data) do
  #   Map.merge(@default_game, game_data)
  #   |> create_game()
  # end

  def delete_game(game_id) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Event.new([:delete, :game], %{game_id: game_id})
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  def create_player(%{name: _n} = data) do
    create(:player, data)
  end

  def create_deck(%{rank: r, advantage: a} = data) do
    data
    |> Map.delete(:advantage)
    |> Map.put(:rank, {r, a})
    |> create_deck()
  end

  def create_deck(%{name: _n, player_id: _p} = data) do
    create(:deck, data)
  end

  def alter_rank(deck_id, :up) do
    Event.new([:alter, :rank], %{deck_id: deck_id, change: 1})
    |> run()
  end

  def alter_rank(deck_id, :down) do
    Event.new([:alter, :rank], %{deck_id: deck_id, change: -1})
    |> run()
  end

  def create_match(
        %{
          :deck_1_id => _deck_1_id,
          :deck_2_id => _deck_2_id,
          :player_1_id => _player_1_id,
          :player_2_id => _player_2_id
        } = data
      ) do
    create(:match, data)
  end

  def end_match(match_id) do
    Event.new([:end, :match], %{match_id: match_id})
    |> run()
  end

  def rerun(type_name, id) when is_bitstring(type_name) and is_bitstring(id) do
    type = Stately.select_module_atom(type_name)

    Event.new([:rerun, type], %{id: id})
    |> run()
  end

  def add_tag(tag, type_name, id)
      when is_bitstring(tag) and is_bitstring(type_name) and is_bitstring(id) do
    type = Stately.select_module_atom(type_name)

    Event.new([:tag, type], %{id: id, tag: tag})
    |> run()
  end

  ## private
  defp list(type) when is_atom(type) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Event.new([:list, type])
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp list(type, constraints) when is_map(constraints) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Event.new([:list, type], constraints)
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp create(type, data) when is_atom(type) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Event.new([:create, type], data)
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp read(type, id) when is_atom(type) do
    # Start listener
    listening_task = Task.async(&listen/0)

    data = Map.put(%{}, Stately.module_id(type), id)

    # Fire ze missiles
    Event.new([:read, type], data)
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp read_log(type, id) when is_atom(type) do
    # Start listener
    listening_task = Task.async(&listen/0)

    data = Map.put(%{}, Stately.module_id(type), id)

    # Fire ze missiles
    Event.new([:read, :log, type], data)
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp read_log(limit) when is_number(limit) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Event.new([:read, :log], %{limit: limit})
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp run(%Event{} = event) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Router.input(event, listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp listen() do
    receive do
      {:error, msg} ->
        IO.puts("\n!! Error -- #{msg} !!")
        {:error, msg}

      msg ->
        msg
    end
  end


  ## feed
  # by type
  def feed(%Event{keys: [type, response_pid]} = event, _orepp)
      when is_atom(type) and is_pid(response_pid) do
    send(response_pid, event.data[type])
    []
  end

  # by id
  def feed(%Event{keys: [type, _status, response_pid], data: %{out: out}}, _orepp)
      when is_atom(type) and is_pid(response_pid) do
    send(response_pid, out)
    []
  end

  def feed(%Event{keys: [type, :log, _status, response_pid], data: %{out: out}}, _orepp)
      when is_atom(type) and is_pid(response_pid) do
    send(response_pid, out)
    []
  end

  def feed(%Event{keys: [type, :error, response_pid], data: %{msg: msg}}, _orepp)
      when is_atom(type) and is_pid(response_pid) do
    send(response_pid, {:error, msg})
    []
  end

  def feed(%Event{keys: [type, :error, response_pid], data: %{cause: cause}}, _orepp)
      when is_atom(type) and is_pid(response_pid) do
    send(response_pid, {:error, cause})
    []
  end

  def feed(%Event{keys: [type, _status, response_pid]} = event, _orepp)
      when is_atom(type) and is_pid(response_pid) do
    send(response_pid, event.data.id)
    []
  end

  # by id failure
  def feed(%Event{keys: [type, :not, _status, response_pid]}, _orepp)
      when is_atom(type) and is_pid(response_pid) do
    send(response_pid, :error)
    []
  end

  def feed(_event, _orepp) do
    []
  end
end

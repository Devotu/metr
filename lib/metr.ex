defmodule Metr do
  @moduledoc """
  API of the application
  Basic structure is a number of public functions that
  > takes structured input and create an event
  > route thah input into the application
  > awaits response (if requested)
  """

  alias Metr.Event
  alias Metr.Router
  alias Metr.Modules.Stately
  alias Metr.Modules.Input.DeckInput
  alias Metr.Modules.Input.GameInput
  alias Metr.Modules.Input.MatchInput
  alias Metr.Modules.Input.PlayerInput

  ## api

  ### create
  def create(%PlayerInput{} = data, :player) do
    create_state(:player, data)
  end

  def create(%DeckInput{} = data, :deck) do
    create_state(:deck, data)
  end

  def create(%GameInput{} = data, :game) do
    create_state(:game, data)
  end

  def create(%MatchInput{} = data, :match) do
    create_state(:match, data)
  end

  ### list
  # all
  def list(:deck), do: list_of(:deck)
  def list(:format), do: list_of(:format)
  def list(:game), do: list_of(:game)
  def list(:match), do: list_of(:match)
  def list(:player), do: list_of(:player)
  def list(:result), do: list_of(:result)
  def list(:tag), do: list_of(:tag)

  # specific
  def list(:game, limit: limit) when is_number(limit) do
    constraints = Map.put(%{}, :limit, limit)
    list_of(:game, constraints)
  end

  def list(:game, by: {:deck, deck_id}) do
    constraints = Map.put(%{}, :deck_id, deck_id)
    list_of(:game, constraints)
  end

  def list(:result, by: {:game, game_id}) do
    constraints = Map.put(%{}, :game_id, game_id)
    list_of(:result, constraints)
  end

  def list(:result, by: {:deck, deck_id}) do
    constraints = Map.put(%{}, :deck_id, deck_id)
    list_of(:result, constraints)
  end

  def list(:deck, ids) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:deck, id) end)
  def list(:game, ids) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:game, id) end)
  def list(:match, ids) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:match, id) end)
  def list(:player, ids) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:player, id) end)
  def list(:result, ids) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:result, id) end)

  ### read

  def read(id, :deck), do: read_state(:deck, id)
  def read(id, :game), do: read_state(:game, id)
  def read(id, :match), do: read_state(:match, id)
  def read(id, :player), do: read_state(:player, id)
  def read(id, :result), do: read_state(:result, id)
  def read(id, :tag), do: read_state(:tag, id)

  def read_log(id, :deck), do: read_log_of(:deck, id)
  def read_log(id, :game), do: read_log_of(:game, id)
  def read_log(id, :match), do: read_log_of(:match, id)
  def read_log(id, :player), do: read_log_of(:player, id)
  def read_log(id, :result), do: read_log_of(:result, id)

  def read_input_log(limit) when is_number(limit) do
      Event.new([:read, :log], %{limit: limit})
      |> run()
  end

  ### delete

  def delete_game(game_id) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Event.new([:delete, :game], %{game_id: game_id})
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  ### functions

  @spec alter_rank(any, :down | :up) :: any
  def alter_rank(deck_id, :up) do
    Event.new([:alter, :rank], %{deck_id: deck_id, change: 1})
    |> run()
  end

  def alter_rank(deck_id, :down) do
    Event.new([:alter, :rank], %{deck_id: deck_id, change: -1})
    |> run()
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

  ## runners ##

  defp list_of(type) when is_atom(type) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Event.new([:list, type])
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp list_of(type, constraints) when is_map(constraints) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Event.new([:list, type], constraints)
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp create_state(type, data) when is_atom(type) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Event.new([:create, type], data)
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp read_state(type, id) when is_atom(type) do
    # Start listener
    listening_task = Task.async(&listen/0)

    data = Map.put(%{}, Stately.module_id(type), id)

    # Fire ze missiles
    Event.new([:read, type], data)
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  defp read_log_of(type, id) when is_atom(type) do
    # Start listener
    listening_task = Task.async(&listen/0)

    data = Map.put(%{}, Stately.module_id(type), id)

    # Fire ze missiles
    Event.new([:read, :log, type], data)
    |> Router.input(listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  @doc """
  Runns an event and awaits response
  """
  defp run(%Event{} = event) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Router.input(event, listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  @doc """
  Creates a listening task that awaits the response from an event routed into the application
  """
  defp listen() do
    receive do
      {:error, msg} ->
        IO.puts("\n!! Error -- #{msg} !!")
        {:error, msg}

      msg ->
        msg
    end
  end

  @doc """
  feed methods of Metr matches on events sent as respons to requests sent into the system and forwards the content to the running listening task
  """
  ## feed ##
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

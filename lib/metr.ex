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
  def create(%PlayerInput{} = data, :player), do: create_state(:player, data)
  def create(%DeckInput{} = data, :deck), do: create_state(:deck, data)
  def create(%GameInput{} = data, :game), do: create_state(:game, data)
  def create(%MatchInput{} = data, :match), do: create_state(:match, data)

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
    Map.put(%{}, :limit, limit)
    |> list_of(:game)
  end

  def list(:game, by: {:deck, id}) do
    %{}
    |> Map.put(:by, :deck)
    |> Map.put(:id, id)
    |> list_of(:game)
  end

  def list(:result, by: {:deck, id}) do
    %{}
    |> Map.put(:by, :deck)
    |> Map.put(:id, id)
    |> list_of(:result)
  end

  def list(:result, by: {:game, id}) do
    %{}
    |> Map.put(:by, :game)
    |> Map.put(:id, id)
    |> list_of(:result)
  end

  def list(ids, :deck) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:deck, id) end)
  def list(ids, :game) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:game, id) end)
  def list(ids, :match) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:match, id) end)
  def list(ids, :player) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:player, id) end)
  def list(ids, :result) when is_list(ids), do: ids |> Enum.map(fn id -> read_state(:result, id) end)

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

  def read_input_log(limit) when is_number(limit), do: read_log(limit);

  ### functions
  @spec alter_rank(any, :down | :up) :: any
  def alter_rank(deck_id, :up) do
    Event.new([:alter, :rank], %{id: deck_id, change: 1})
    |> run()
  end

  def alter_rank(deck_id, :down) do
    Event.new([:alter, :rank], %{id: deck_id, change: -1})
    |> run()
  end

  def end_match(match_id) do
    Event.new([:end, :match], %{match_id: match_id})
    |> run()
  end

  def rerun(type, id) when is_atom(type) and is_bitstring(id) do
    Event.new([:rerun, type], %{id: id})
    |> run()
  end

  def add_tag(tag, type, id) when is_bitstring(tag) and is_atom(type) and is_bitstring(id) do
    Event.new([:tag, type], %{id: id, tag: tag})
    |> run()
  end

  ## private core functions ##
  defp list_of(type) when is_atom(type) do
    Event.new([:list, type])
    |> run()
  end

  defp list_of(constraints, type) when is_atom(type) and is_map(constraints) do
    Event.new([:list, type], constraints)
    |> run()
  end

  defp create_state(type, data) when is_atom(type) do
    Event.new([:create, type], data)
    |> run()
  end

  defp read_state(type, id) when is_atom(type) do
    Map.put(%{}, :id, id)
    |> Event.new([:read, type])
    |> run()
  end

  defp read_log_of(type, id) when is_atom(type) do
    Map.put(%{}, :id, id)
    |> Event.new([:read, :log, type])
    |> run()
  end

  defp read_log(limit) when is_number(limit) do
    Event.new([:read, :log], %{limit: limit})
    |> run()
  end

  #Runns an event and awaits response
  defp run(%Event{} = event) do
    # Start listener
    listening_task = Task.async(&listen/0)

    # Fire ze missiles
    Router.input(event, listening_task.pid)

    # Await response
    Task.await(listening_task)
  end

  #Creates a listening task that awaits the response from an event routed into the application
  defp listen() do
    receive do
      {:error, cause} ->
        IO.puts("\n!! Error -- #{cause} !!")
        {:error, cause}

      msg ->
        msg
    end
  end

  @doc """
  feed methods of Metr matches on events sent as respons to requests sent into the system and forwards the content to the running listening task
  """
  def feed(%Event{keys: [:match,  :ended,     pid], data: %{out: out}}, _orepp) when is_pid(pid), do: respond(pid, out)
  def feed(%Event{keys: [:error,              pid], data: %{cause: cause}}, _orepp) when is_pid(pid), do: respond(pid, {:error, cause})
  def feed(%Event{keys: [type,    :error,     pid], data: %{cause: cause}}, _orepp) when is_atom(type) and is_pid(pid), do: respond(pid, {:error, cause})
  def feed(%Event{keys: [type,    :altered,   pid], data: %{out: out}}, _orepp) when is_atom(type) and is_pid(pid), do: respond(pid, out)
  def feed(%Event{keys: [type,    :created,   pid], data: %{out: out}}, _orepp) when is_atom(type) and is_pid(pid), do: respond(pid, out)
  def feed(%Event{keys: [type,    :list,      pid], data: %{out: out}}, _orepp) when is_atom(type) and is_pid(pid), do: respond(pid, out)
  def feed(%Event{keys: [type,    :read,      pid], data: %{out: out}}, _orepp) when is_atom(type) and is_pid(pid), do: respond(pid, out)
  def feed(%Event{keys: [type,    :reran,     pid], data: %{out: out}}, _orepp) when is_atom(type) and is_pid(pid), do: respond(pid, out)
  def feed(_event, _orepp), do: []

  defp respond(pid, out) do
    send(pid, out)
    []
  end
end

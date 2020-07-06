defmodule Metr.CLI do
  use GenServer

  alias Metr.HRC
  alias Metr.Event
  alias Metr.Router

  ## mod
  @switches [
    help: :boolean,
    input: :string,
  ]
  @aliases [
    h: :help,
    q: :input,
  ]


  #read input
  def main(args) do
    args
    |> parse
    |> process
  end


  def parse(args) do
    opts = [
      switches: @switches,
      aliases: @aliases
    ]

    {result, _, _} = OptionParser.parse(args, opts)
    result
  end


  def process([{:help, true}]) do
    help_text = """
    Available commands:
    input/in: String in human readable format:
    create type id with key value and key value
    """
    IO.puts help_text
    help_text
  end


  #convert to event
  #route event
  def process([{:input, request}]) do
    request
    |> HRC.parse()
    |> Event.new()
    |> Router.route()
  end



  ## gen
  @impl true
  def init(:ok) do
    {:ok, %{}}
  end


  def feed(%Event{} = event) do
    {:ok, pid} = GenServer.start(Metr.CLI, :ok)
    GenServer.cast(pid, event)
    []
  end

  #recieve event
  #opt
  #write output
  @impl true
  def handle_cast(%Event{} = event, _) do
    IO.puts(format_event_display(event))
    {:noreply, []}
  end

  defp format_event_display(%Event{} = event) do
    "#{event.id}: #{Kernel.inspect(event.tags)} :: #{Kernel.inspect(event.data)}}"
  end
end

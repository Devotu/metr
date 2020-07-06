defmodule Metr.CLI do
  #genserver

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
  #recieve event
  #opt
  #write output

end

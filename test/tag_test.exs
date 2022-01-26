defmodule TagTest do
  use ExUnit.Case

  alias Metr.Data
  alias Metr.Event
  alias Metr.Modules.Tag
  alias Metr.Time

  test "basic feed" do
    assert [] == Tag.feed(Event.new([:not, :relevant], %{id: "abc_123"}), nil)
  end

  # test "create tag" do
  #   resulting_event =
  #     Tag.feed(
  #       Event.new([:create, :tag],
  #       %{
  #         id: Id.guid(),
  #         input: %TagInput{
  #           name: "Adam Tag"
  #         }
  #       }),
  #       nil
  #     )
  #   |> List.first()

  #   assert [:tag, :created, nil] == resulting_event.keys
  #   log_entries = Data.read_log_by_id(resulting_event.data.out, :tag)
  #   assert 1 = Enum.count(log_entries)

  #   TestHelper.delay()
  #   TestHelper.wipe_test(:tag, resulting_event.data.out)
  # end

  # test "deck created" do
  #   tag_id = TestHelper.init_only_tag "Bertil Tag"
  #   deck_id = TestHelper.init_only_deck "Bravor Tag", tag_id

  #   # Resolve deck created
  #   [resulting_event] =
  #     Tag.feed(Event.new([:deck, :created, nil], %{out: deck_id}), nil)

  #   # Assert
  #   resulting_feedback_should_be = "Deck #{deck_id} added to tag #{tag_id}"
  #   assert [:tag, :altered, nil] == resulting_event.keys
  #   assert resulting_feedback_should_be == resulting_event.data.out

  #   # Cleanup
  #   TestHelper.delay()
  #   TestHelper.wipe_test(:tag, tag_id)
  #   TestHelper.wipe_test(:deck, deck_id)
  # end

  test "player tagged" do
    tag_one_name = "Adam Tag"
    player_id = TestHelper.init_only_player "Alpha Tag"

    tag_id = Metr.add_tag(tag_one_name, :player, player_id)

    player = Metr.read(player_id, :player)
    #The tag is added to the player tags
    assert Enum.member?(player.tags, tag_one_name)

    tag = Metr.read(tag_id, :tag)
    #The player has been added to the tagged states
    assert Enum.member?(tag.tagged, {:player, player_id, Time.timestamp()})

    # Cleanup
    TestHelper.delay()
    TestHelper.wipe_test(:tag, tag_id)
    TestHelper.wipe_test(:player, player_id)
  end

  # test "list tags" do
  #   pid1 = Id.guid()
  #   pid2 = Id.guid()
  #   pid3 = Id.guid()
  #   did1 = Id.guid()
  #   did2 = Id.guid()

  #   Tag.feed(Event.new([:create, :tag], %{id: pid1, input: %TagInput{name: "Adam List"}}), nil)
  #   Tag.feed(Event.new([:create, :tag], %{id: pid2, input: %TagInput{name: "Bertil List"}}), nil)
  #   Tag.feed(Event.new([:create, :tag], %{id: pid3, input: %TagInput{name: "Ceasar List"}}), nil)
  #   Deck.feed(Event.new([:create, :deck], %{id: did1, input: %DeckInput{name: "Beta List", tag_id: "bertil_list", format: "standard"}}), nil)
  #   Deck.feed(Event.new([:create, :deck], %{id: did2, input: %DeckInput{name: "Alpha List", tag_id: "adam_list", format: "standard"}}), nil)

  #   [resulting_event] = State.feed(Event.new([:list, :tag]), nil)
  #   assert [:tag, :list, nil] == resulting_event.keys
  #   # any actual data will break proper comparison
  #   assert 3 <= Enum.count(resulting_event.data.out)

  #   TestHelper.delay()
  #   TestHelper.wipe_test(:tag, [pid1, pid2, pid3])
  #   TestHelper.wipe_test(:deck, [did1, did2])
  # end

  # test "recall tag" do
  #   expected_tag = %Metr.Modules.Tag{
  #     decks: [],
  #     id: "david_tag",
  #     matches: [],
  #     name: "David Tag",
  #     results: [],
  #     time: 0
  #   }

  #   [resulting_event] = Tag.feed(Event.new([:create, :tag], %{id: Id.guid(), input: %TagInput{name: "David Tag"}}), nil)
  #   tag_id = resulting_event.data.out
  #   gen_id = Data.genserver_id(:tag, tag_id)
  #   assert :ok == GenServer.stop(gen_id)
  #   assert nil == GenServer.whereis(gen_id)

  #   read_tag = State.read(tag_id, :tag)

  #   assert read_tag.name == expected_tag.name
  #   assert read_tag.results == expected_tag.results
  #   assert read_tag.matches |> Enum.count() == 0

  #   TestHelper.delay()
  #   TestHelper.wipe_test(:tag, tag_id)
  # end
end

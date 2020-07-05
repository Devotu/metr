defmodule Metr.Event do
    defstruct id: "", tags: [], data: %{}

    alias Metr.Id
    alias Metr.Event

    def new(tags, data) when is_list(tags) do
        %Event{id: Id.guid(), tags: tags, data: data}
    end
end

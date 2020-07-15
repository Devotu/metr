defmodule Metr.Event do
    defstruct id: "", tags: [], data: %{}

    alias Metr.Id
    alias Metr.Event
    alias Metr.HRC

    def new(%HRC{subject: nil, action: nil} = hrc), do: %Event{id: Id.guid(), tags: [], data: hrc.details}
    def new(%HRC{subject: nil} = hrc), do: %Event{id: Id.guid(), tags: [hrc.action], data: hrc.details}
    def new(%HRC{action: nil} = hrc), do: %Event{id: Id.guid(), tags: [hrc.subject], data: hrc.details}
    def new(%HRC{} = hrc), do: %Event{id: Id.guid(), tags: [hrc.action, hrc.subject], data: hrc.details}

    def new(tags, data) when is_list(tags) do
        %Event{id: Id.guid(), tags: tags, data: data}
    end
end

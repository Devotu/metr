defmodule Metr.Modules.Input.ResultInput do
  @enforce_keys [:player_id, :deck_id, :game_id, :place]
  defstruct player_id: "",
            deck_id: "",
            game_id: "",
            place: nil,
            power: nil,
            fun: nil,
            tags: []
end

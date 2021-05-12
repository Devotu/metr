defmodule Metr.Modules.Input.GameInput do
  @enforce_keys [:player_one, :player_two, :deck_one, :deck_two, :winner]
  defstruct player_one: nil,
            player_two: nil,
            deck_one: nil,
            deck_two: nil,
            winner: nil,
            match: nil,
            ranking: false,
            turns: nil,
            power_one: nil,
            power_two: nil,
            fun_one: nil,
            fun_two: nil,
            results: [],
            tags: []
end

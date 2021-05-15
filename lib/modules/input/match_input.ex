defmodule Metr.Modules.Input.MatchInput do
  @enforce_keys [:player_one, :player_two, :deck_one, :deck_two]
  defstruct player_one: nil, player_two: nil, deck_one: nil, deck_two: nil, ranking: false
end

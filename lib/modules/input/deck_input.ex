defmodule Metr.Modules.Input.DeckInput do
  @enforce_keys [:name, :player_id, :format]
  defstruct name: nil,
            player_id: nil,
            format: "",
            theme: "",
            price: nil,
            black: false,
            white: false,
            red: false,
            green: false,
            blue: false,
            colorless: false
end

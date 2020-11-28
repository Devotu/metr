defmodule Metr.Time do
  def timestamp(), do: DateTime.utc_now() |> DateTime.to_unix()
end

defmodule Metr.Rank do
  def find_change(%{place: p}) do
    case p do
      0 -> 0
      1 -> 1
      _ -> -1
    end
  end

  # No changes
  def apply_change(nil, 0), do: nil
  def apply_change(rank, 0), do: rank

  # Initialized
  def apply_change(nil, 1), do: {0, 1}
  def apply_change(nil, -1), do: {0, -1}
  def apply_change({"0", "0"}, 1), do: {0, 1}
  def apply_change({"0", "0"}, -1), do: {0, -1}

  # Positive
  # Already TOTP => no change
  def apply_change({2, 1}, 1), do: {2, 1}
  def apply_change({r, -1}, 1), do: {r, 0}
  def apply_change({r, 0}, 1), do: {r, 1}
  # Level up
  def apply_change({r, 1}, 1), do: {r + 1, 0}

  # Negative
  # Already rock bottom => no change
  def apply_change({-2, -1}, -1), do: {-2, -1}
  # Level down
  def apply_change({r, -1}, -1), do: {r - 1, 0}
  def apply_change({r, 0}, -1), do: {r, -1}
  def apply_change({r, 1}, -1), do: {r, 0}

  def uniform_rank({r, a}) do
    {as_number(r), as_number(a)}
  end
  def uniform_rank(0), do: nil
  def uniform_rank(nil), do: nil

  defp as_number(r) when is_number(r), do: r
  defp as_number(r) when is_bitstring(r), do: String.to_integer(r)
  defp as_number(_), do: :error

  def is_at_same(nil, nil), do: true
  def is_at_same({0, _advantage_one}, nil), do: true
  def is_at_same(nil, {0, _adavantage_two}), do: true
  def is_at_same(_rank_one, nil), do: false
  def is_at_same(nil, _rank_two), do: false
  def is_at_same({rank_one, _advantage_one}, {rank_two, _advantage_two}) do
    rank_one == rank_two
  end
end

defmodule Metr.Rank do

  #No changes
  def apply_change(nil, 0), do: nil
  def apply_change(rank, 0), do: rank

  #Initialized
  def apply_change(nil, 1), do: {0,1}
  def apply_change(nil, -1), do: {0,-1}

  #Positive
  def apply_change({2,1}, 1), do: {2,1} #Already TOTP => no change
  def apply_change({r, -1}, 1), do: {r, 0}
  def apply_change({r, 0}, 1), do: {r, 1}
  def apply_change({r, 1}, 1), do: {r+1, 0} #Level up

  #Negative
  def apply_change({-2,-1}, -1), do: {-2,-1} #Already rock bottom => no change
  def apply_change({r, -1}, -1), do: {r-1, 0} #Level down
  def apply_change({r, 0}, -1), do: {r, -1}
  def apply_change({r, 1}, -1), do: {r, 0}
end

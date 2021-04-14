defmodule RankTest do
  use ExUnit.Case

  alias Metr.Rank

  test "is same" do
    rank_one = {0,0}
    rank_two = {0,0}
    assert Rank.is_at_same(rank_one, rank_two)

    rank_one = {1,0}
    rank_two = {1,0}
    assert Rank.is_at_same(rank_one, rank_two)

    rank_one = {2,0}
    rank_two = {2,0}
    assert Rank.is_at_same(rank_one, rank_two)

    rank_one = {-1,0}
    rank_two = {-1,0}
    assert Rank.is_at_same(rank_one, rank_two)

    rank_one = {0,1}
    rank_two = {0,1}
    assert Rank.is_at_same(rank_one, rank_two)

    rank_one = {2,-1}
    rank_two = {2,1}
    assert Rank.is_at_same(rank_one, rank_two)

    rank_one = nil
    rank_two = nil
    assert Rank.is_at_same(rank_one, rank_two)

    rank_one = nil
    rank_two = {0,1}
    assert Rank.is_at_same(rank_one, rank_two)
  end

  test "is not same" do
    rank_one = {0,0}
    rank_two = {1,0}
    assert !Rank.is_at_same(rank_one, rank_two)

    rank_one = {2,0}
    rank_two = {1,1}
    assert !Rank.is_at_same(rank_one, rank_two)

    rank_one = {0,1}
    rank_two = {1,0}
    assert !Rank.is_at_same(rank_one, rank_two)

    rank_one = {-1,0}
    rank_two = {1,0}
    assert !Rank.is_at_same(rank_one, rank_two)

    rank_one = {1,0}
    rank_two = {-1,0}
    assert !Rank.is_at_same(rank_one, rank_two)

    rank_one = {1,0}
    rank_two = nil
    assert !Rank.is_at_same(rank_one, rank_two)

    rank_one = nil
    rank_two = {-2,0}
    assert !Rank.is_at_same(rank_one, rank_two)
  end
end

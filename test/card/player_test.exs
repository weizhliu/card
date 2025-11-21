defmodule Card.PlayerTest do
  use ExUnit.Case, async: true
  alias Card.Player

  describe "initial state" do
    test "player starts with correct initial hand" do
      player = %Player{side: :host}
      assert player.hand == [1, 1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]
      assert player.desk == []
      assert player.wins == 0
    end

    test "player can be host or guest" do
      host = %Player{side: :host}
      guest = %Player{side: :guest}
      assert host.side == :host
      assert guest.side == :guest
    end
  end

  describe "play_card/2" do
    test "removes card from hand and adds to desk" do
      player = %Player{side: :host}
      updated = Player.play_card(player, 1)

      assert updated.hand == [1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]
      assert updated.desk == [1]
    end

    test "plays multiple cards in sequence" do
      player = %Player{side: :host}

      updated =
        player
        |> Player.play_card(1)
        |> Player.play_card(2)
        |> Player.play_card(3)

      assert updated.hand == [1, 2, 3, 4, 5, 6, :reverse, :reverse]
      assert updated.desk == [1, 2, 3]
    end

    test "plays reverse card" do
      player = %Player{side: :host}
      updated = Player.play_card(player, :reverse)

      assert updated.hand == [1, 1, 2, 2, 3, 3, 4, 5, 6, :reverse]
      assert updated.desk == [:reverse]
    end

    test "only removes one instance of duplicate cards" do
      player = %Player{side: :host}
      # Play both 1s
      updated =
        player
        |> Player.play_card(1)
        |> Player.play_card(1)

      # Both 1s should be removed from hand
      refute 1 in updated.hand
      assert updated.desk == [1, 1]
    end
  end

  describe "score_of_round/2" do
    test "calculates score for round 1" do
      player = %Player{side: :host, desk: [1, 2, 3]}
      assert Player.score_of_round(player, 1) == 6
    end

    test "calculates score for round 2" do
      # Round 2 cards are at indices 3, 4, 5
      player = %Player{side: :host, desk: [1, 2, 3, 4, 5, 6]}
      assert Player.score_of_round(player, 2) == 15
    end

    test "calculates score for round 3" do
      # Round 3 cards are at indices 6, 7, 8
      player = %Player{side: :host, desk: [1, 1, 1, 2, 2, 2, 3, 3, 3]}
      assert Player.score_of_round(player, 3) == 9
    end

    test "excludes reverse cards from score calculation" do
      player = %Player{side: :host, desk: [1, :reverse, 3]}
      assert Player.score_of_round(player, 1) == 4
    end

    test "returns 0 when all cards are reverse" do
      player = %Player{side: :host, desk: [:reverse, :reverse, :reverse]}
      assert Player.score_of_round(player, 1) == 0
    end

    test "returns 0 for empty desk" do
      player = %Player{side: :host, desk: []}
      assert Player.score_of_round(player, 1) == 0
    end

    test "handles partial round" do
      player = %Player{side: :host, desk: [5, 6]}
      assert Player.score_of_round(player, 1) == 11
    end
  end

  describe "reverse_count_of_round/2" do
    test "counts no reverse cards" do
      player = %Player{side: :host, desk: [1, 2, 3]}
      assert Player.reverse_count_of_round(player, 1) == 0
    end

    test "counts one reverse card" do
      player = %Player{side: :host, desk: [1, :reverse, 3]}
      assert Player.reverse_count_of_round(player, 1) == 1
    end

    test "counts multiple reverse cards" do
      player = %Player{side: :host, desk: [:reverse, :reverse, 3]}
      assert Player.reverse_count_of_round(player, 1) == 2
    end

    test "counts reverse cards in specific round" do
      player = %Player{side: :host, desk: [1, 2, 3, :reverse, 5, :reverse]}
      assert Player.reverse_count_of_round(player, 1) == 0
      assert Player.reverse_count_of_round(player, 2) == 2
    end
  end

  describe "cards_in_round (via score/reverse functions)" do
    test "correctly slices round 1 cards" do
      player = %Player{side: :host, desk: [1, 2, 3, 4, 5, 6, :reverse, :reverse, 1]}
      assert Player.score_of_round(player, 1) == 6
    end

    test "correctly slices round 2 cards" do
      player = %Player{side: :host, desk: [1, 2, 3, 4, 5, 6, :reverse, :reverse, 1]}
      assert Player.score_of_round(player, 2) == 15
    end

    test "correctly slices round 3 cards" do
      player = %Player{side: :host, desk: [1, 2, 3, 4, 5, 6, :reverse, :reverse, 1]}
      # :reverse and :reverse are excluded, only 1 is counted
      assert Player.score_of_round(player, 3) == 1
      assert Player.reverse_count_of_round(player, 3) == 2
    end
  end
end

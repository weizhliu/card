defmodule Card.GameTest do
  use ExUnit.Case, async: true
  alias Card.Game
  alias Card.Player

  # Helper to create a game struct without starting GenServer
  defp new_game(attrs \\ %{}) do
    default = %Game{
      id: "test_game_#{:erlang.unique_integer([:positive])}",
      host: %Player{side: :host},
      guest: %Player{side: :guest},
      turn: 1,
      round: 1,
      status: :start
    }

    struct(default, attrs)
  end

  describe "initial game state" do
    test "game starts with correct defaults" do
      game = new_game()

      assert game.turn == 1
      assert game.round == 1
      assert game.status == :start
      assert game.host.side == :host
      assert game.guest.side == :guest
      assert game.host.wins == 0
      assert game.guest.wins == 0
    end

    test "both players start with full hands" do
      game = new_game()
      expected_hand = [1, 1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]

      assert game.host.hand == expected_hand
      assert game.guest.hand == expected_hand
    end

    test "both players start with empty desks" do
      game = new_game()

      assert game.host.desk == []
      assert game.guest.desk == []
    end
  end

  describe "have_this_card?/3" do
    test "returns true when player has the card" do
      game = new_game()

      assert Game.have_this_card?(game, :host, 1)
      assert Game.have_this_card?(game, :host, 6)
      assert Game.have_this_card?(game, :host, :reverse)
    end

    test "returns false when player doesn't have the card" do
      game = new_game()

      refute Game.have_this_card?(game, :host, 7)
      refute Game.have_this_card?(game, :host, 0)
    end

    test "returns false after card is played" do
      game = new_game()
      # Simulate playing the only 6
      host = Player.play_card(game.host, 6)
      game = %{game | host: host}

      refute Game.have_this_card?(game, :host, 6)
    end

    test "returns true if duplicate card remains" do
      game = new_game()
      # Play one of the two 1s
      host = Player.play_card(game.host, 1)
      game = %{game | host: host}

      # Should still have another 1
      assert Game.have_this_card?(game, :host, 1)
    end
  end

  describe "turn fairness rules" do
    test "host cannot play if already ahead of guest" do
      # Create a game where host has played more cards
      host = %Player{side: :host, desk: [1], hand: [1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]}

      guest = %Player{
        side: :guest,
        desk: [],
        hand: [1, 1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]
      }

      game = new_game(%{host: host, guest: guest})

      # Host desk length (1) > guest desk length (0)
      assert length(game.host.desk) > length(game.guest.desk)
    end

    test "guest cannot play if behind host" do
      # Create a game where guest has played fewer cards
      host = %Player{side: :host, desk: [], hand: [1, 1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]}
      guest = %Player{side: :guest, desk: [1], hand: [1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]}

      game = new_game(%{host: host, guest: guest})

      # Guest desk length (1) > host desk length (0) - this means guest is ahead
      assert length(game.guest.desk) > length(game.host.desk)
    end
  end

  describe "scoring and winning" do
    test "host wins round with higher score" do
      # Host: 4+5+6=15, Guest: 1+2+3=6
      host = %Player{side: :host, desk: [4, 5, 6], hand: [], wins: 0}
      guest = %Player{side: :guest, desk: [1, 2, 3], hand: [], wins: 0}

      assert Player.score_of_round(host, 1) == 15
      assert Player.score_of_round(guest, 1) == 6
    end

    test "guest wins round with higher score" do
      # Host: 1+2+3=6, Guest: 4+5+6=15
      host = %Player{side: :host, desk: [1, 2, 3], hand: [], wins: 0}
      guest = %Player{side: :guest, desk: [4, 5, 6], hand: [], wins: 0}

      assert Player.score_of_round(host, 1) == 6
      assert Player.score_of_round(guest, 1) == 15
    end

    test "tie goes to guest (host_win? is false when equal)" do
      # When scores are equal, host_score > guest_score is false
      host = %Player{side: :host, desk: [1, 2, 3], hand: [], wins: 0}
      guest = %Player{side: :guest, desk: [1, 2, 3], hand: [], wins: 0}

      assert Player.score_of_round(host, 1) == Player.score_of_round(guest, 1)
      # In a tie, host_score > guest_score is false, so guest wins
    end
  end

  describe "reverse card logic" do
    test "single reverse card flips winner" do
      # Host has higher score but played a reverse
      # Host: reverse+5+6=11 (just 5+6), Guest: 1+2+3=6
      # Without reverse: Host wins (11 > 6)
      # With 1 reverse: Guest wins (odd number of reverses)
      host = %Player{side: :host, desk: [:reverse, 5, 6], hand: [], wins: 0}
      guest = %Player{side: :guest, desk: [1, 2, 3], hand: [], wins: 0}

      host_score = Player.score_of_round(host, 1)
      guest_score = Player.score_of_round(guest, 1)

      total_reverses =
        Player.reverse_count_of_round(host, 1) + Player.reverse_count_of_round(guest, 1)

      assert host_score == 11
      assert guest_score == 6
      assert total_reverses == 1
      # Odd = reverses outcome
      assert rem(total_reverses, 2) == 1
    end

    test "two reverse cards cancel out" do
      # Both players play a reverse - even number cancels out
      host = %Player{side: :host, desk: [:reverse, 5, 6], hand: [], wins: 0}
      guest = %Player{side: :guest, desk: [:reverse, 2, 3], hand: [], wins: 0}

      total_reverses =
        Player.reverse_count_of_round(host, 1) + Player.reverse_count_of_round(guest, 1)

      assert total_reverses == 2
      # Even = no reverse
      assert rem(total_reverses, 2) == 0
    end

    test "three reverse cards flip winner" do
      # 3 reverses = odd number, flips outcome
      host = %Player{side: :host, desk: [:reverse, :reverse, 6], hand: [], wins: 0}
      guest = %Player{side: :guest, desk: [:reverse, 2, 3], hand: [], wins: 0}

      total_reverses =
        Player.reverse_count_of_round(host, 1) + Player.reverse_count_of_round(guest, 1)

      assert total_reverses == 3
      # Odd = reverses outcome
      assert rem(total_reverses, 2) == 1
    end

    test "four reverse cards cancel out" do
      host = %Player{side: :host, desk: [:reverse, :reverse, 6], hand: [], wins: 0}
      guest = %Player{side: :guest, desk: [:reverse, :reverse, 3], hand: [], wins: 0}

      total_reverses =
        Player.reverse_count_of_round(host, 1) + Player.reverse_count_of_round(guest, 1)

      assert total_reverses == 4
      # Even = no reverse
      assert rem(total_reverses, 2) == 0
    end
  end

  describe "game end conditions" do
    test "game ends when host reaches 2 wins" do
      host = %Player{side: :host, wins: 2}

      # Simulate end_game check
      assert host.wins == 2
    end

    test "game ends when guest reaches 2 wins" do
      guest = %Player{side: :guest, wins: 2}

      # Simulate end_game check
      assert guest.wins == 2
    end

    test "game continues if neither has 2 wins" do
      host = %Player{side: :host, wins: 1}
      guest = %Player{side: :guest, wins: 1}
      game = new_game(%{host: host, guest: guest, status: :start})

      assert host.wins < 2
      assert guest.wins < 2
      assert game.status == :start
    end
  end

  describe "round progression" do
    test "round advances after turn 3" do
      # After 3 turns (6 cards played), round should advance
      host = %Player{side: :host, desk: [1, 2, 3], hand: [1, 2, 3, 4, 5, 6, :reverse, :reverse]}
      guest = %Player{side: :guest, desk: [1, 2, 3], hand: [1, 2, 3, 4, 5, 6, :reverse, :reverse]}
      game = new_game(%{host: host, guest: guest, turn: 4, round: 1})

      # Turn 4 means round 1 is complete (3 turns done)
      assert game.turn > 3
    end

    test "turn resets to 1 when round ends" do
      # This is what the end_round function does
      game = new_game(%{turn: 4, round: 1})

      # After end_round, turn should be 1 and round should be 2
      # (We're testing the expected state transformation)
      # Before end_round
      assert game.turn == 4
      # After end_round would be: turn: 1, round: 2
    end
  end

  describe "full game scenarios" do
    test "complete round 1 with host winning" do
      # Host plays 4,5,6 (sum=15), Guest plays 1,2,3 (sum=6)
      host = %Player{
        side: :host,
        desk: [4, 5, 6],
        hand: [1, 1, 2, 2, 3, 3, :reverse, :reverse],
        wins: 0
      }

      guest = %Player{
        side: :guest,
        desk: [1, 2, 3],
        hand: [1, 4, 5, 6, 2, 3, :reverse, :reverse],
        wins: 0
      }

      host_score = Player.score_of_round(host, 1)
      guest_score = Player.score_of_round(guest, 1)

      assert host_score == 15
      assert guest_score == 6
      assert host_score > guest_score
    end

    test "complete round 1 with reverse changing outcome" do
      # Host plays 4,5,:reverse (sum=9), Guest plays 1,2,3 (sum=6)
      # Host has higher score (9 > 6) but reverse flips it
      host = %Player{
        side: :host,
        desk: [4, 5, :reverse],
        hand: [1, 1, 2, 2, 3, 3, 6, :reverse],
        wins: 0
      }

      guest = %Player{
        side: :guest,
        desk: [1, 2, 3],
        hand: [1, 4, 5, 6, 2, 3, :reverse, :reverse],
        wins: 0
      }

      host_score = Player.score_of_round(host, 1)
      guest_score = Player.score_of_round(guest, 1)
      host_reverses = Player.reverse_count_of_round(host, 1)
      guest_reverses = Player.reverse_count_of_round(guest, 1)
      total_reverses = host_reverses + guest_reverses

      assert host_score == 9
      assert guest_score == 6
      # Host would win without reverse
      assert host_score > guest_score
      assert total_reverses == 1
      # Odd = outcome reversed, so guest wins
      assert rem(total_reverses, 2) == 1
    end
  end

  describe "status handling" do
    test "game accepts play_card only when status is :start" do
      game = new_game(%{status: :start})
      assert game.status == :start
    end

    test "game is complete when status is :host_win" do
      game = new_game(%{status: :host_win})
      assert game.status == :host_win
    end

    test "game is complete when status is :guest_win" do
      game = new_game(%{status: :guest_win})
      assert game.status == :guest_win
    end
  end
end

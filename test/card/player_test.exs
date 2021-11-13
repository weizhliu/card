defmodule Card.Playertest do
  use ExUnit.Case, async: true
  alias Card.Player

  describe "play_card/1" do
    setup do
      [player: Player.play_card(%Card.Player{}, 1)]
    end

    test "adds card to desk", %{player: player} do
      assert player.desk == [1]
    end

    test "remove crad from hand", %{player: player} do
      assert player.hand == [1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]
    end
  end

  describe "score_of_round/2" do
    test "add score of round" do
      player = %Player{desk: [1, 2, 3, 4, 5, 6]}
      assert Player.score_of_round(player, 2) == 15
    end

    test "add score of round except reverse card" do
      player = %Player{desk: [4, :reverse, 6, 5]}
      assert Player.score_of_round(player, 1) == 10
    end
  end
end

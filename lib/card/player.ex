defmodule Card.Player do
  initial_hand = [1, 1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]
  defstruct [:side, desk: [], hand: initial_hand, wins: 0]

  def play_card(player = %__MODULE__{}, card) do
    player
    |> remove_card_from_hand(card)
    |> add_card_to_desk(card)
  end

  defp remove_card_from_hand(%{hand: hand} = player, card) do
    Map.replace(player, :hand, hand -- [card])
  end

  defp add_card_to_desk(%{desk: desk} = player, card) do
    Map.replace(player, :desk, desk ++ [card])
  end

  def score_of_round(%__MODULE__{} = player, round) do
    player
    |> cards_in_round(round)
    |> Enum.reject(&(&1 == :reverse))
    |> Enum.sum()
  end

  def reverse_count_of_round(%__MODULE__{} = player, round) do
    player
    |> cards_in_round(round)
    |> Enum.count(&(&1 == :reverse))
  end

  defp cards_in_round(%__MODULE__{desk: desk}, round) do
    Enum.slice(desk, (round - 1) * 3, 3)
  end
end

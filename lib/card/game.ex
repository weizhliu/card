defmodule Card.Game do
  initial_hand = [1, 1, 2, 2, 3, 3, 4, 5, 6, :reverse, :reverse]

  defstruct host: %{desk: [], hand: initial_hand, wins: 0},
            guest: %{desk: [], hand: initial_hand, wins: 0},
            turn: 1,
            round: 1,
            status: :start,
            id: nil

  use GenServer

  def init(game) do
    Process.send_after(self(), :stop_timer, 60 * 60 * 1000)
    {:ok, start_turn_timer(game)}
  end

  def terminate(_reason, game) do
    :ets.delete(:games, game.id)
    :ok
  end

  def handle_call(:get_status, _from, game) do
    {:reply, game, game}
  end

  def handle_cast({:play_card, _player, _card}, %{status: status} = game) when status != :start,
    do: {:noreply, game}

  def handle_cast({:play_card, :host, _card}, %{host: host, guest: guest} = game)
      when length(host.desk) > length(guest.desk),
      do: {:noreply, game}

  def handle_cast({:play_card, :guest, _card}, %{host: host, guest: guest} = game)
      when length(host.desk) < length(guest.desk),
      do: {:noreply, game}

  def handle_cast({:play_card, player, card}, game) do
    if have_this_card?(game, player, card) do
      {:noreply, play_card_with_checks(game, player, card)}
    else
      {:noreply, game}
    end
  end

  def have_this_card?(game, player, card) do
    game
    |> Map.get(player)
    |> Map.get(:hand)
    |> Enum.member?(card)
  end

  def play_card_with_checks(%{turn: current_turn} = game, player, card) do
    game
    |> play_card_for(player, card)
    |> end_turn()
    |> add_wins()
    |> end_round()
    |> end_game()
    |> start_turn_timer(current_turn)
    |> maybe_broadcast(game)
  end

  defp maybe_broadcast(game, old_game) when game == old_game, do: game

  defp maybe_broadcast(game, _old_game) do
    broadcast(game.id, game)
    game
  end

  defp start_turn_timer(game, current_turn \\ 0) do
    if game.status == :start && current_turn != game.turn do
      Process.send_after(self(), {:times_up, :host, game.round, game.turn}, 50000)
      Process.send_after(self(), {:times_up, :guest, game.round, game.turn}, 50000)
    end

    game
  end

  def handle_info(
        {:times_up, player, round, turn},
        %{round: current_round, turn: current_turn} = game
      )
      when round == current_round and turn == current_turn do
    card =
      game
      |> Map.get(player)
      |> Map.get(:hand)
      |> Enum.random()

    {:noreply, play_card_with_checks(game, player, card)}
  end

  def handle_info({:times_up, _player, _round, _turn}, game), do: {:noreply, game}

  def handle_info(:stop_timer, _game) do
    GenServer.stop(self())
  end

  defp play_card_for(game, player, card) do
    player_data = Map.get(game, player)

    game
    |> assign_to_player(player, :hand, player_data.hand -- [card])
    |> assign_to_player(player, :desk, player_data.desk ++ [card])
  end

  defp end_turn(%{guest: guest, host: host} = game) do
    if length(guest.desk) == length(host.desk) do
      Map.merge(game, %{turn: game.turn + 1})
    else
      game
    end
  end

  defp add_wins(%{turn: turn, host: host, guest: guest} = game) when turn > 3 do
    if host_win_this_round?(game) do
      assign_to_player(game, :host, :wins, host.wins + 1)
    else
      assign_to_player(game, :guest, :wins, guest.wins + 1)
    end
  end

  defp add_wins(game), do: game

  defp host_win_this_round?(%{round: round, host: host, guest: guest}) do
    range = (round - 1)..(round * 3 - 1)
    host_desk = Enum.slice(host.desk, range)
    guest_desk = Enum.slice(guest.desk, range)
    host_win = get_score(host_desk) > get_score(guest_desk)

    if reverse?(host_desk ++ guest_desk) do
      !host_win
    else
      host_win
    end
  end

  defp reverse?(desk) do
    desk
    |> Enum.filter(&(&1 == :reverse))
    |> length()
    |> rem(2) == 1
  end

  defp get_score(desk) do
    desk
    |> Enum.reject(&(&1 == :reverse))
    |> Enum.sum()
  end

  defp end_round(%{turn: turn} = game) when turn > 3 do
    game
    |> Map.merge(%{turn: 1, round: game.round + 1})
  end

  defp end_round(game), do: game

  defp assign_to_player(game, player, key, value) do
    new_data =
      game
      |> Map.get(player)
      |> Map.replace(key, value)

    Map.replace(game, player, new_data)
  end

  defp end_game(%{guest: %{wins: 2}} = game) do
    Map.replace(game, :status, :guest_win)
  end

  defp end_game(%{host: %{wins: 2}} = game) do
    Map.replace(game, :status, :host_win)
  end

  defp end_game(game), do: game

  # Client

  def start(id) do
    GenServer.start_link(__MODULE__, %__MODULE__{id: id})
  end

  def status(pid) do
    GenServer.call(pid, :get_status)
  end

  def play_card(pid, from, card) do
    GenServer.cast(pid, {:play_card, from, card})
  end

  def subscribe(id) do
    Phoenix.PubSub.subscribe(Card.PubSub, id)
  end

  def broadcast(id, game) do
    Phoenix.PubSub.broadcast(Card.PubSub, id, game)
  end
end

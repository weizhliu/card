defmodule CardWeb.GameLive.Game do
  use CardWeb, :live_view
  alias Card.{Game, Room}

  def mount(
        %{"id" => id} = _params,
        _session,
        %{assigns: %{live_action: current_player}} = socket
      ) do
    [opponent] = [:host, :guest] -- [current_player]
    pid = Card.Dealer.find_or_create_game(id)
    game = Game.status(pid)
    if connected?(socket), do: Card.Game.subscribe(id)
    if connected?(socket), do: Card.Room.subscribe(game.new_room.id)

    socket =
      socket
      |> assign(%{
        pid: pid,
        id: id,
        game: maybe_fold_last(game, current_player, opponent),
        current_player: current_player,
        opponent: opponent,
        modal_on: true,
        new_room: game.new_room,
        countdown: nil
      })
      |> schedule_countdown_tick()

    {:ok, socket}
  end

  defp maybe_fold_last(game, current_player, opponent) do
    if length(desk(game, opponent)) > length(desk(game, current_player)) do
      opponent_status =
        game
        |> Map.get(opponent)
        |> Map.replace(:desk, Enum.drop(desk(game, opponent), -1) ++ [:fold])

      Map.replace(game, opponent, opponent_status)
    else
      game
    end
  end

  defp desk(game, player) do
    game
    |> Map.get(player)
    |> Map.get(:desk)
  end

  def handle_event("close_model", _params, socket) do
    {:noreply, assign(socket, :modal_on, false)}
  end

  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, :modal_on, true)}
  end

  def handle_event(
        "play_card",
        %{"card" => card},
        %{assigns: %{current_player: current_player, pid: pid}} = socket
      ) do
    Game.play_card(pid, current_player, transform_card(card))

    {:noreply, socket}
  end

  defp transform_card("reverse"), do: :reverse
  defp transform_card(number), do: String.to_integer(number)

  def handle_info(%Game{} = game, socket) do
    %{assigns: %{current_player: current_player, opponent: opponent}} = socket

    {:noreply, assign(socket, %{game: maybe_fold_last(game, current_player, opponent)})}
  end

  def handle_info(
        %Room{host_ready: true, guest_ready: true, id: new_room_id},
        %{assigns: %{current_player: current_player}} = socket
      ) do
    case current_player do
      :host -> {:noreply, push_navigate(socket, to: ~p"/#{new_room_id}/host")}
      :guest -> {:noreply, push_navigate(socket, to: ~p"/#{new_room_id}/guest")}
    end
  end

  def handle_info(%Room{} = new_room, socket) do
    {:noreply, assign(socket, new_room: new_room)}
  end

  def handle_info(:countdown_tick, socket) do
    socket = socket |> update_countdown() |> schedule_countdown_tick()
    {:noreply, socket}
  end

  defp schedule_countdown_tick(socket) do
    if connected?(socket) do
      Process.send_after(self(), :countdown_tick, 1000)
    end

    socket
  end

  defp update_countdown(%{assigns: %{game: game, current_player: current_player}} = socket) do
    # Check if current player needs to play (hasn't played this turn yet)
    player_desk = Map.get(game, current_player).desk
    opponent_desk = Map.get(game, socket.assigns.opponent).desk

    needs_to_play =
      game.status == :start and length(player_desk) <= length(opponent_desk)

    countdown =
      if needs_to_play and game.turn_started_at do
        elapsed = System.monotonic_time(:millisecond) - game.turn_started_at
        remaining = div(Card.Game.turn_timeout() - elapsed, 1000)

        if remaining <= 10 and remaining >= 0 do
          remaining
        else
          nil
        end
      else
        nil
      end

    assign(socket, :countdown, countdown)
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center h-screen">
      <.logo />
      <.status game={@game} opponent={@opponent} current_player={@current_player} />
      <div class="flex items-center justify-center gap-4 m-4">
        <.all_rounds
          opponent={Map.get(@game, @opponent)}
          current_player={Map.get(@game, @current_player)}
          current_round={@game.round}
        />
      </div>
      <%= if @countdown do %>
        <div class="text-red-500 text-xl font-bold mb-2"><%= @countdown %></div>
      <% end %>
      <.hand player={Map.get(@game, @current_player)} />
      <%= if (@game.status != :start) && @modal_on do %>
        <.game_over_modal>
          <%= if @game.status == :"#{@current_player}_win" do %>
            <.win_message />
          <% else %>
            <.lose_message />
          <% end %>
          <.live_component
            module={CardWeb.ReadyComponent}
            player={@current_player}
            id={:ready}
            room={@new_room}
          >
            <:title>
              <div class="bg-blue-300 -mt-8 w-32 h-4 rounded-xl transform skew-x-12 -rotate-6 translate-y-6 translate-x-20">
              </div>
              <h2 class="transform text-xl font-serif">Another Round?</h2>
            </:title>
          </.live_component>
          <.back_to_menu />
        </.game_over_modal>
      <% end %>
    </div>
    """
  end

  def notice(%{modal_on: false} = assigns) do
    ~H"""
    <div phx-click="open_modal" class="flex items-center mt-4 h-4 text-gray-600 cursor-pointer">
      <div class="bg-green-300 w-4 h-4 rounded-xl transform skew-x-12 -rotate-8 translate-x-3"></div>
      <h2 class="block transform text-xl mr-2">+</h2>
      <div class="bg-blue-300 w-28 h-2 rounded-xl transform -skew-x-12 rotate-3 -ml-28 translate-x-28">
      </div>
      <h2 class="block transform font-serif font-lg text-black">Reopen result menu</h2>
    </div>
    """
  end

  def notice(%{game: %{round: 1, turn: 1}} = assigns) do
    ~H"""
    <div class="mt-4 h-4 text-gray-600">👇 Pick a card to start</div>
    """
  end

  def notice(%{game: %{turn: 1}} = assigns) do
    ~H"""
    <div class="mt-4 h-4 text-gray-600">👇 Pick a card to start new round</div>
    """
  end

  def notice(assigns) do
    ~H"""
    <div class="mt-4 h-4"></div>
    """
  end

  def all_rounds(assigns) do
    # Build data for all 3 rounds
    rounds_data =
      Enum.map(1..3, fn round_num ->
        start_idx = (round_num - 1) * 3
        is_past = round_num < assigns.current_round
        is_current = round_num == assigns.current_round
        opponent_cards = Enum.slice(assigns.opponent.desk, start_idx, 3)
        player_cards = Enum.slice(assigns.current_player.desk, start_idx, 3)
        has_any_cards = length(opponent_cards) > 0 or length(player_cards) > 0
        needs_pick_prompt = is_current and length(player_cards) == 0

        # Calculate scores for past rounds
        {player_score, opponent_score, is_reversed, player_won, result_text} =
          if is_past do
            player_rev = Card.Player.reverse_count_of_round(assigns.current_player, round_num)
            opponent_rev = Card.Player.reverse_count_of_round(assigns.opponent, round_num)
            total_rev = player_rev + opponent_rev
            is_reversed = rem(total_rev, 2) == 1

            player_score = Card.Player.score_of_round(assigns.current_player, round_num)
            opponent_score = Card.Player.score_of_round(assigns.opponent, round_num)

            # Game rule: host wins only if strictly greater, ties go to guest
            # We need to determine if current_player won based on their side
            {host_score, guest_score} =
              if assigns.current_player.side == :host do
                {player_score, opponent_score}
              else
                {opponent_score, player_score}
              end

            is_tie = host_score == guest_score
            host_wins = host_score > guest_score
            host_wins = if is_reversed, do: not host_wins, else: host_wins

            player_won =
              if assigns.current_player.side == :host do
                host_wins
              else
                not host_wins
              end

            # Determine result text
            result_text =
              cond do
                is_tie and is_reversed -> "reversed tie, host win"
                is_tie -> "tie, guest win"
                is_reversed -> "reversed, smaller win"
                true -> "larger win"
              end

            {player_score, opponent_score, is_reversed, player_won, result_text}
          else
            {nil, nil, false, false, nil}
          end

        %{
          round: round_num,
          opponent_cards: opponent_cards,
          player_cards: player_cards,
          is_past: is_past,
          is_current: is_current,
          is_future: not is_past and not is_current,
          has_any_cards: has_any_cards,
          needs_pick_prompt: needs_pick_prompt,
          show_round: is_current or is_past,
          player_score: player_score,
          opponent_score: opponent_score,
          is_reversed: is_reversed,
          player_won: player_won,
          result_text: result_text
        }
      end)

    assigns = assign(assigns, :rounds_data, rounds_data)

    ~H"""
    <div class="flex items-start gap-4">
      <%= for {round_data, idx} <- Enum.with_index(@rounds_data) do %>
        <%= if round_data.show_round do %>
          <%= if idx > 0 && Enum.at(@rounds_data, idx - 1).show_round do %>
            <div class="h-56 w-px bg-gray-200 self-center"></div>
          <% end %>
          <div class={[
            "flex flex-col items-center w-48 relative",
            round_data.is_past && "opacity-40"
          ]}>
            <div class="flex w-full justify-center items-center h-28 gap-1">
              <%= for card <- round_data.opponent_cards do %>
                <.card name={card} faded={round_data.is_past} />
              <% end %>
            </div>
            <%= if round_data.is_past do %>
              <div class="absolute top-1/2 -translate-y-1/2 text-base flex flex-col items-center leading-tight">
                <span class={if round_data.player_won, do: "text-red-500", else: "text-green-500 font-bold"}><%= round_data.opponent_score %></span>
                <span class="text-xs text-gray-400"><%= round_data.result_text %></span>
                <span class={if round_data.player_won, do: "text-green-500 font-bold", else: "text-red-500"}><%= round_data.player_score %></span>
              </div>
            <% end %>
            <div class="flex w-full justify-center items-center h-28 gap-1">
              <%= if round_data.needs_pick_prompt do %>
                <div class="text-gray-400 text-center">
                  <div class="text-sm font-medium">Round <%= round_data.round %></div>
                  <div class="text-xs">Pick a card</div>
                </div>
              <% else %>
                <%= for card <- round_data.player_cards do %>
                  <.card name={card} faded={round_data.is_past} />
                <% end %>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def desk(assigns) do
    # Only show cards from the current round (last 0-3 cards based on turn)
    # Each round has 3 turns, so cards for round N start at index (N-1)*3
    start_index = (assigns.round - 1) * 3
    current_round_cards = Enum.drop(assigns.player.desk, start_index)

    assigns = assign(assigns, :current_round_cards, current_round_cards)

    ~H"""
    <div class="flex w-full justify-center items-center h-32 gap-2">
      <%= for card <- @current_round_cards do %>
        <.card name={card} />
      <% end %>
    </div>
    """
  end

  def opponent_desk(assigns), do: desk(assigns)

  def hand(assigns) do
    ~H"""
    <div class="flex w-full justify-center mt-4">
      <div class="grid grid-cols-6">
        <%= for card <- @player.hand do %>
          <button phx-click="play_card" phx-value-card={card}>
            <.card name={card} />
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  def status(assigns) do
    my_wins = Map.get(assigns.game, assigns.current_player).wins
    opponent_wins = Map.get(assigns.game, assigns.opponent).wins
    current_round = assigns.game.round

    assigns =
      assigns
      |> assign(:my_wins, my_wins)
      |> assign(:opponent_wins, opponent_wins)
      |> assign(:current_round, current_round)

    ~H"""
    <div class="flex items-center gap-3 m-4">
      <%= for round <- 1..3 do %>
        <.round_dot round={round} current_round={@current_round} wins={@my_wins} opponent_wins={@opponent_wins} />
      <% end %>
    </div>
    """
  end

  def round_dot(assigns) do
    # Determine the dot color based on round results
    # - Green: player won this round
    # - Red: player lost this round
    # - Gray with ring: current round (in progress)
    # - Gray: future round (not played yet)

    {color_class, ring_class} =
      cond do
        # Past rounds - check if won or lost
        assigns.round < assigns.current_round ->
          if assigns.wins >= assigns.round do
            {"bg-green-300", ""}
          else
            {"bg-red-300", ""}
          end

        # Current round - in progress
        assigns.round == assigns.current_round ->
          {"bg-gray-300", "ring-2 ring-blue-300 ring-offset-2"}

        # Future rounds - not played yet
        true ->
          {"bg-gray-300", ""}
      end

    # Different twist transforms for each round dot
    twist_class =
      case assigns.round do
        1 -> "transform skew-x-6 -rotate-6"
        2 -> "transform -skew-x-3 rotate-12"
        3 -> "transform skew-x-12 -rotate-3"
      end

    assigns =
      assigns
      |> assign(:color_class, color_class)
      |> assign(:ring_class, ring_class)
      |> assign(:twist_class, twist_class)

    ~H"""
    <div class="relative">
      <%= if @ring_class != "" do %>
        <div class="absolute z-10 w-6 h-6 rounded-xl border-4 border-blue-500 -top-1 -left-0.5 transform -skew-x-6 rotate-6">
        </div>
      <% end %>
      <div class={"w-5 h-5 rounded-xl #{@color_class} #{@twist_class}"}>
      </div>
    </div>
    """
  end

  def game_over_modal(assigns) do
    ~H"""
    <div
      phx-capture-click="close_model"
      class="fixed w-full h-screen flex bg-black bg-opacity-20 justify-center items-center"
    >
      <div class="flex flex-col p-4 bg-gray-50 shadow-lg text-center border h-70 rounded-xl">
        <div class="flex">
          <button phx-click="close_model" class="-mt-6">
            <div class="bg-red-300 w-4 h-4 rounded-xl transform skew-x-12 -rotate-6 translate-y-6">
            </div>
            <h2 class="block transform text-xl">x</h2>
          </button>
        </div>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def win_message(assigns) do
    ~H"""
    <div class="bg-yellow-300 w-12 h-8 rounded-xl transform skew-x-12 -rotate-12 translate-x-12 translate-y-12">
    </div>
    <h2 class="transform text-3xl font-serif mb-4">You Win</h2>
    """
  end

  def lose_message(assigns) do
    ~H"""
    <div class="bg-gray-300 w-8 h-8 rounded-xl transform skew-x-12 -rotate-12 translate-x-12 translate-y-12" />
    <h2 class="transform text-3xl font-serif mb-4">You Lose</h2>
    """
  end

  def back_to_menu(assigns) do
    ~H"""
    <div class="flex flex-col justify-center">
      <.link href="/" class="group mt-4">
        <div class="bg-gray-300 border-2 border-white group-hover:border-gray-300 -mt-4 w-24 h-6 rounded-xl transform -skew-x-12 rotate-6 translate-y-8 translate-x-16" />
        <h2 class="block transform text-lg group-hover:underline">Back to Start Menu</h2>
      </.link>
    </div>
    """
  end
end

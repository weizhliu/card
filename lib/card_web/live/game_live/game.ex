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

    {:ok,
     assign(socket, %{
       pid: pid,
       id: id,
       game: maybe_fold_last(game, current_player, opponent),
       current_player: current_player,
       opponent: opponent,
       modal_on: true,
       new_room: game.new_room
     })}
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

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center h-screen" id="game-container" phx-hook="GameFlash">
      <.logo />
      <.status game={@game} opponent={@opponent} current_player={@current_player} />
      <!-- Turn Progress Bar -->
      <.turn_progress turn={@game.turn} />
      <div id="desk-area" class="border-t border-b m-4 relative">
        <!-- Round separators label -->
        <div class="absolute -top-6 left-0 right-0 flex justify-center">
          <div class="flex items-center gap-16 text-xs text-gray-400">
            <span>Round 1</span>
            <span>Round 2</span>
            <span>Round 3</span>
          </div>
        </div>
        <.desk player={Map.get(@game, @opponent)} is_opponent={true} />
        <.desk player={Map.get(@game, @current_player)} is_opponent={false} />
      </div>
      <.notice game={@game} modal_on={@modal_on} />
      <.hand player={Map.get(@game, @current_player)} />
      <%= if (@game.status != :start) && @modal_on do %>
        <.game_over_modal current_player={@current_player} game_status={@game.status}>
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
    <div phx-click="open_modal" class="flex items-center mt-4 h-4 text-gray-600 cursor-pointer group transition-all hover:scale-105">
      <div class="bg-green-300 w-4 h-4 rounded-xl transform skew-x-12 -rotate-8 translate-x-3 group-hover:bg-green-400 transition-colors"></div>
      <h2 class="block transform text-xl mr-2">+</h2>
      <div class="bg-blue-300 w-28 h-2 rounded-xl transform -skew-x-12 rotate-3 -ml-28 translate-x-28">
      </div>
      <h2 class="block transform font-serif font-lg text-black group-hover:text-blue-600 transition-colors">Reopen result menu</h2>
    </div>
    """
  end

  def notice(%{game: %{round: 1, turn: 1}} = assigns) do
    ~H"""
    <div class="mt-4 h-4 text-gray-600 pick-card-notice notice-bounce flex items-center gap-2">
      <span class="text-blue-500 animate-pulse">👇</span>
      <span>Pick a card to start</span>
    </div>
    """
  end

  def notice(%{game: %{turn: 1}} = assigns) do
    ~H"""
    <div class="mt-4 h-4 text-gray-600 notice-bounce flex items-center gap-2">
      <span class="text-blue-500">🎯</span>
      <span class="font-medium text-blue-600">New Round!</span>
      <span>Pick a card to start</span>
    </div>
    """
  end

  def notice(assigns) do
    ~H"""
    <div class="mt-4 h-4"></div>
    """
  end

  attr :player, :map, required: true
  attr :is_opponent, :boolean, default: false

  def desk(assigns) do
    ~H"""
    <div
      id={"desk-#{if @is_opponent, do: "opponent", else: "player"}"}
      phx-hook="DeskCard"
      class={[
        "flex w-full justify-center items-center h-32",
        @is_opponent && "opacity-90"
      ]}
    >
      <%= for {card, i} <- Enum.with_index(@player.desk, 1) do %>
        <%= if Enum.member?([4,7], i) do %>
          <div class="round-divider w-1 h-20 mx-3 rounded-full"></div>
        <% end %>
        <div class="desk-card">
          <.card name={card} context={:desk} />
        </div>
      <% end %>
    </div>
    """
  end

  def opponent_desk(assigns), do: desk(assigns)

  def hand(assigns) do
    ~H"""
    <div id="player-hand" phx-hook="HandCards" class="flex w-full justify-center mt-4">
      <div class="grid grid-cols-6 gap-1">
        <%= for card <- @player.hand do %>
          <button
            phx-click="play_card"
            phx-value-card={card}
            phx-hook="CardPlay"
            id={"hand-card-#{card}"}
            class="hand-card transform transition-all duration-200 hover:z-10"
          >
            <.card name={card} context={:hand} />
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  def turn_progress(assigns) do
    ~H"""
    <div
      id="turn-progress"
      phx-hook="TurnProgress"
      data-turn={@turn}
      data-max-turns="3"
      class="w-64 h-2 bg-gray-200 rounded-full overflow-hidden mb-2"
    >
      <div
        class="turn-indicator h-full transition-all duration-500 ease-out"
        style={"width: #{(@turn / 3) * 100}%"}
      >
      </div>
    </div>
    """
  end

  def status(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <.wins game={@game} opponent={@opponent} current_player={@current_player} />
      <.game_round round={@game.round} turn={@game.turn} />
    </div>
    """
  end

  def game_round(assigns) do
    ~H"""
    <div
      id="round-indicator"
      phx-hook="RoundIndicator"
      data-round={@round}
      class="mt-2 text-gray-600 flex items-center m-4 round-indicator"
    >
      <div class="bg-blue-300 w-9 h-2 rounded-xl transform -skew-x-12 rotate-6 translate-x-10 translate-y-4">
      </div>
      <h2 class="transform mr-4 text-xl font-serif block">Round:</h2>
      <!-- Round number with enhanced visibility -->
      <div class="flex items-center gap-2">
        <%= for r <- 1..3 do %>
          <div class={[
            "w-8 h-8 rounded-full flex items-center justify-center font-bold transition-all duration-300",
            r == @round && "bg-blue-500 text-white scale-110 shadow-lg ring-2 ring-blue-300",
            r < @round && "bg-green-400 text-white",
            r > @round && "bg-gray-200 text-gray-400"
          ]}>
            <%= r %>
          </div>
        <% end %>
      </div>
      <!-- Turn indicator within round -->
      <div class="ml-4 flex items-center gap-1 text-sm">
        <span class="text-gray-400">Turn:</span>
        <%= for t <- 1..3 do %>
          <div class={[
            "w-2 h-2 rounded-full transition-all duration-200",
            t <= @turn && "bg-blue-400",
            t > @turn && "bg-gray-300"
          ]}>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def wins(assigns) do
    ~H"""
    <div class="flex h-8 items-center justify-between text-gray-600 m-4 gap-6">
      <div class="bg-blue-300 w-4 h-3 rounded-xl transform skew-x-12 -rotate-12 translate-x-8"></div>
      <h2 class="transform mr-4 text-xl font-serif">Wins:</h2>
      <.player_wins player="You" wins={Map.get(@game, @current_player).wins} is_current={true} />
      <div class="w-px h-6 bg-gray-300"></div>
      <.player_wins player="Opponent" wins={Map.get(@game, @opponent).wins} is_current={false} />
    </div>
    """
  end

  attr :player, :string, required: true
  attr :wins, :integer, required: true
  attr :is_current, :boolean, default: false

  def player_wins(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <h3 class={[
        "block font-medium",
        @is_current && "text-blue-600"
      ]}>
        <%= @player %>:
      </h3>
      <div class="flex gap-1">
        <%= for x <- 1..2 do %>
          <%= if x <= @wins do %>
            <div class="win-marker w-5 h-5 rounded-full transform -skew-x-3 rotate-12 flex items-center justify-center">
              <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
              </svg>
            </div>
          <% else %>
            <div class="pending-marker w-5 h-5 rounded-full transform -skew-x-3 rotate-12"></div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  attr :current_player, :atom, required: true
  attr :game_status, :atom, required: true
  slot :inner_block, required: true

  def game_over_modal(assigns) do
    is_winner = assigns.game_status == :"#{assigns.current_player}_win"

    assigns = assign(assigns, :is_winner, is_winner)

    ~H"""
    <div
      phx-capture-click="close_model"
      class="game-modal-backdrop fixed w-full h-screen flex bg-black/30 justify-center items-center z-50"
    >
      <div
        id="game-result-modal"
        phx-hook="WinCelebration"
        data-winner={to_string(@is_winner)}
        class={[
          "game-modal-content flex flex-col p-6 bg-white shadow-2xl text-center border rounded-2xl relative overflow-visible",
          @is_winner && "ring-4 ring-yellow-400/50"
        ]}
      >
        <!-- Close button -->
        <div class="absolute -top-2 -right-2">
          <button
            phx-click="close_model"
            class="w-8 h-8 bg-red-400 hover:bg-red-500 rounded-full flex items-center justify-center text-white shadow-lg transition-all hover:scale-110"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def win_message(assigns) do
    ~H"""
    <div class="relative py-4">
      <!-- Trophy decoration -->
      <div class="flex justify-center mb-2">
        <div class="relative">
          <div class="bg-gradient-to-br from-yellow-300 to-yellow-500 w-16 h-12 rounded-xl transform skew-x-6 -rotate-6 shadow-lg">
          </div>
          <div class="absolute inset-0 flex items-center justify-center">
            <span class="text-3xl">🏆</span>
          </div>
        </div>
      </div>
      <!-- Victory text with gradient -->
      <h2 class="text-4xl font-serif font-bold bg-gradient-to-r from-yellow-500 via-yellow-400 to-yellow-600 bg-clip-text text-transparent">
        Victory!
      </h2>
      <p class="text-gray-500 mt-1 text-sm">You won the round!</p>
    </div>
    """
  end

  def lose_message(assigns) do
    ~H"""
    <div class="relative py-4">
      <!-- Decoration -->
      <div class="flex justify-center mb-2">
        <div class="bg-gradient-to-br from-gray-300 to-gray-400 w-12 h-10 rounded-xl transform skew-x-6 -rotate-6 shadow-md opacity-60">
        </div>
      </div>
      <!-- Defeat text -->
      <h2 class="text-4xl font-serif font-bold text-gray-500">
        Defeat
      </h2>
      <p class="text-gray-400 mt-1 text-sm">Better luck next time!</p>
    </div>
    """
  end

  def back_to_menu(assigns) do
    ~H"""
    <div class="flex flex-col justify-center mt-4 pt-4 border-t border-gray-200">
      <.link
        href="/"
        class="group flex items-center justify-center gap-2 px-4 py-2 rounded-lg text-gray-600 hover:text-gray-800 hover:bg-gray-100 transition-all"
      >
        <svg class="w-4 h-4 transform group-hover:-translate-x-1 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
        </svg>
        <span class="font-medium">Back to Start Menu</span>
      </.link>
    </div>
    """
  end
end

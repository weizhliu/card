defmodule CardWeb.GameLive.Game do
  use CardWeb, :live_view
  import CardWeb.Component
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
    {:noreply,
     push_redirect(socket, to: Routes.game_game_path(socket, current_player, new_room_id))}
  end

  def handle_info(%Room{} = new_room, socket) do
    {:noreply, assign(socket, new_room: new_room)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center h-screen">
      <.logo />
      <.status game={@game} opponent={@opponent} current_player={@current_player}/>
      <div class="border-t border-b m-4">
        <.desk player={Map.get(@game, @opponent)}/>
        <.desk player={Map.get(@game, @current_player)}/>
      </div>
      <.notice game={@game} modal_on={@modal_on}/>
      <.hand player={Map.get(@game, @current_player)}/>
      <%= if (@game.status != :start) && @modal_on do %>
        <.game_over_modal>
          <%= if @game.status == :"#{@current_player}_win" do %>
            <.win_message />
          <% else %>
            <.lose_message />
          <% end %>
          <.live_component module={CardWeb.ReadyComponent} player={@current_player} id={:ready} room={@new_room}>
            <:title>
              <div class="bg-blue-300 -mt-8 w-32 h-4 rounded-xl transform skew-x-12 -rotate-6 translate-y-6 translate-x-20"></div>
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
      <div class="bg-blue-300 w-28 h-2 rounded-xl transform -skew-x-12 rotate-3 -ml-28 translate-x-28"></div>
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

  def desk(assigns) do
    ~H"""
    <div class="flex w-full justify-center items-center h-32">
      <%= for {card, i} <- Enum.with_index(@player.desk, 1) do %>
        <%= if Enum.member?([4,7], i) do %>
          <div class="w-1 h-20 bg-gray-200 mx-2 rounded"></div>
        <% end %>
        <.card name={card}/>
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
            <.card name={card}/>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  def status(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <.wins game={@game} opponent={@opponent} current_player={@current_player}/>
      <.game_round round={@game.round}/>
    </div>
    """
  end

  def game_round(assigns) do
    ~H"""
    <div class="mt-2 text-gray-600 flex m-4">
      <div class="bg-blue-300 w-9 h-2 rounded-xl transform -skew-x-12 rotate-6 translate-x-10 translate-y-4"></div>
      <h2 class="transform mr-8 text-xl font-serif block">Round:</h2>
      <div class="ml-2 text-lg"><%= @round %></div>
    </div>
    """
  end

  def wins(assigns) do
    ~H"""
    <div class="flex h-6 items-center justify-between text-gray-600 m-4">
      <div class="bg-blue-300 w-4 h-3 rounded-xl transform skew-x-12 -rotate-12 translate-x-8"></div>
      <h2 class="transform mr-8 text-xl font-serif"> Wins:</h2>
      <.player_wins player={"You"} wins={Map.get(@game, @current_player).wins}/>
      <div class="ml-8"></div>
      <.player_wins player={"Opponent"} wins={Map.get(@game, @opponent).wins}/>
    </div>
    """
  end

  def player_wins(assigns) do
    ~H"""
    <h3 class="block"><%= @player %>:</h3>
    <%= for x <- 0..(@wins), x > 0 do %>
      <div class={"ml-4 bg-green-300 w-4 h-4 rounded-3xl transform -skew-x-3 rotate-12"}></div>
    <% end %>
    <%= for x <- 0..(2 - @wins), x > 0 do %>
      <div class={"ml-4 bg-gray-300 w-4 h-4 rounded-3xl transform -skew-x-3 rotate-12"}></div>
    <% end %>
    """
  end

  def game_over_modal(assigns) do
    ~H"""
    <div phx-capture-click="close_model" class="fixed w-full h-screen flex bg-black bg-opacity-20 justify-center items-center">
      <div class="flex flex-col p-4 bg-gray-50 shadow-lg text-center border h-70 rounded-xl">
        <div class="flex">
          <button phx-click="close_model" class="-mt-6">
            <div class="bg-red-300 w-4 h-4 rounded-xl transform skew-x-12 -rotate-6 translate-y-6"></div>
            <h2 class="block transform text-xl">x</h2>
          </button>
        </div>
        <%= render_block(@inner_block) %>
      </div>
    </div>
    """
  end

  def win_message(assigns) do
    ~H"""
    <div class="bg-yellow-300 w-12 h-8 rounded-xl transform skew-x-12 -rotate-12 translate-x-12 translate-y-12"></div>
    <h2 class="transform text-3xl font-serif mb-4">You Win</h2>
    """
  end

  def lose_message(assigns) do
    ~H"""
    <div class="bg-gray-300 w-8 h-8 rounded-xl transform skew-x-12 -rotate-12 translate-x-12 translate-y-12"></div>
    <h2 class="transform text-3xl font-serif mb-4">You Lose</h2>
    """
  end

  def back_to_menu(assigns) do
    ~H"""
    <div class="flex flex-col justify-center">
      <%= link to: "/", class: "group mt-4" do %>
        <div class="bg-gray-300 border-2 border-white group-hover:border-gray-300 -mt-4 w-24 h-6 rounded-xl transform -skew-x-12 rotate-6 translate-y-8 translate-x-16"></div>
        <h2 class="block transform text-lg group-hover:underline">Back to Start Menu</h2>
      <% end %>
    </div>
    """
  end
end

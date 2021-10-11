defmodule CardWeb.GameLive.Invite do
  use CardWeb, :live_view
  import CardWeb.Component
  alias Card.Room

  def mount(%{"id" => id} = _params, _session, socket) do
    if connected?(socket), do: Card.Room.subscribe(id)

    case Room.get(id) do
      room = %Room{} ->
        {:ok,
         assign(socket, %{
           room: room,
           player: socket.assigns.live_action,
           invite_path: Routes.game_invite_url(socket, :guest, id)
         })}

      _ ->
        {:ok, push_redirect(socket, to: "/")}
    end
  end

  def handle_info(
        %{host_ready: true, guest_ready: true} = room,
        %{assigns: %{player: player}} = socket
      ) do
    socket =
      socket
      |> assign(:room, room)
      |> then(&push_redirect(&1, to: Routes.game_game_path(&1, player, room.id)))

    {:noreply, socket}
  end

  def handle_info(room, socket) do
    {:noreply, assign(socket, :room, room)}
  end

  def handle_event("ready", _params, %{assigns: %{player: player, room: room}} = socket) do
    Room.update(room.id, Map.replace(room, :"#{player}_ready", true))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center h-screen">
      <.logo />
      <div class="flex-grow flex flex-col items-center justify-center">
        <.ready room={@room} player={@player}/>
        <%= if @player == :host && !@room.guest_ready do %>
          <.invite path={@invite_path}/>
        <% end %>
      </div>
    </div>
    """
  end

  def invite(assigns) do
    ~H"""
    <div class="flex flex-col p-4 bg-gray-50 shadow-lg text-center mt-12">
      <div class="bg-blue-300 w-40 h-8 rounded-xl transform skew-x-12 rotate-6 translate-y-6 translate-x-40"></div>
      <div class="transform">
        <label for="invite_url" class="text-2xl font-serif">Guest Link</label><br>
        <input id="invite_url" class="w-96 text-center text-gray-500 bg-gray-50 mt-4" type="text" value={@path} readonly>
      </div>
      <div class="bg-blue-300 w-24 h-2 rounded-xl transform -skew-x-12 rotate-2 translate-y-6 translate-x-36"></div>
      <button class="btn mb-2 transform font-serif text-lg" data-clipboard-target="#invite_url">
        Copy to Clipboard
      </button>
      <p class="text-lg text-gray-600">To begin the game, send this link to your component.</p>
    </div>
    """
  end

  def ready(assigns) do
    ~H"""
    <div class="flex flex-col p-4 text-center mt-8">
      <div class="bg-blue-300 w-32 h-8 rounded-xl transform skew-x-12 -rotate-6 translate-y-6 translate-x-20"></div>
      <h2 class="transform text-2xl font-serif">Room status</h2>
      <div class="flex justify-between mt-2 w-60">
        <.ready_status player="Host" ready={@room.host_ready}/>
        <.ready_status player="Guest" ready={@room.guest_ready}/>
      </div>
      <%= unless Map.get(@room, :"#{@player}_ready") do %>
        <div class="flex justify-between w-40 mx-auto mt-8">
          <div class="text-lg text-center">Are you ready?</div>
          <div class="h-8">
            <div class="bg-green-300 w-8 h-8 rounded-xl transform skew-x-12 -rotate-45 translate-x-2"></div>
            <button phx-click="ready" class="transform -translate-y-7 text-xl">Yes</button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def ready_status(assigns) do
    ~H"""
    <div class="flex">
      <%= @player %>:
      <%= if @ready do %>
        <div class={"ml-8 bg-green-300 w-6 h-6 rounded-3xl transform -skew-x-3 rotate-12"}></div>
      <% else %>
        <div class={"ml-8 bg-red-300 w-6 h-6 rounded-3xl transform -skew-x-3 rotate-12"}></div>
      <% end %>
    </div>
    """
  end
end

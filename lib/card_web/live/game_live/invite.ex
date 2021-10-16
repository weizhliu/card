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
      <div class="h-40"></div>
      <%= live_component CardWeb.ReadyComponent, player: @player, id: :ready, room: @room, title: "Room Status" %>
      <%= if @player == :host && !@room.guest_ready do %>
        <.invite path={@invite_path}/>
      <% end %>
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
end

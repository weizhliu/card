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
      <.live_component module={CardWeb.ReadyComponent} player={@player} id={:ready} room={@room}>
        <:title>
          <div class="bg-blue-300 -mt-8 w-32 h-8 rounded-xl transform skew-x-12 -rotate-6 translate-y-6 translate-x-20"></div>
          <h2 class="transform text-2xl font-serif">Room Status</h2>
        </:title>
      </.live_component>
      <%= if @player == :host && !@room.guest_ready do %>
        <.invite path={@invite_path}/>
      <% end %>
    </div>
    """
  end

  def invite(assigns) do
    ~H"""
    <div class="flex flex-col p-4 bg-gray-50 shadow-lg text-center mt-12">
      <div class="bg-blue-300 w-40 h-8 rounded-xl transform skew-x-12 rotate-3 -mt-6 translate-y-7 translate-x-44"></div>
      <label for="invite_url" class="transform text-2xl font-serif">Guest Link</label><br>
      <div class="flex border-2 rounded-xl bg-white justify-center items-center mt-4">
        <input id="invite_url" class="w-96 text-center text-gray-500 border-none rounded-l-xl" type="text" value={@path} readonly>
        <button onclick="navigator.clipboard.writeText(document.querySelector('#invite_url').value)" class="btn flex group -rotate-2">
          <div class="bg-green-300 w-16 h-8 rounded-xl rounded-l-none transform -skew-x-2 -ml-16 translate-x-16 border-2 border-white group-hover:border-green-300"></div>
          <div class="transform text-lg w-16 text-center group-hover:underline">
            Copy
          </div>
        </button>
      </div>
      <p class="text-lg text-gray-600">To begin the game, send this link to your opponent.</p>
    </div>
    """
  end
end

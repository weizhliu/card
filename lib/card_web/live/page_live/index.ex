defmodule CardWeb.PageLive.Index do
  use CardWeb, :live_view
  import CardWeb.Component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen items-center justify-center">
      <.logo />
      <.start_button />
    </div>
    """
  end

  def start_button(assigns) do
    ~H"""
    <button phx-click="start_game">
      <div class="bg-blue-300 w-24 h-8 rounded-xl transform -skew-x-12 -rotate-6 translate-y-7 translate-x-8"></div>
      <div class="transform text-xl">Start a game</div>
    </button>
    """
  end

  def handle_event("start_game", _params, socket) do
    room_id = random_room_id()
    :ets.insert_new(:rooms, {room_id, %Card.Room{id: room_id}})

    {:noreply, push_redirect(socket, to: Routes.game_invite_path(socket, :host, room_id))}
  end

  defp random_room_id(), do: String.trim(to_string(:rand.uniform()), "0.")
end

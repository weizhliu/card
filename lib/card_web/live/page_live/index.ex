defmodule CardWeb.PageLive.Index do
  use CardWeb, :live_view
  import CardWeb.Component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen items-center justify-center">
      <.logo />
      <.start_button />
      <.github />
    </div>
    """
  end

  def start_button(assigns) do
    ~H"""
    <button phx-click="start_game" class="group">
      <div class="bg-blue-300 border-2 border-white group-hover:border-blue-300 w-24 h-8 rounded-xl transform -skew-x-12 -rotate-6 translate-y-7 translate-x-8"></div>
      <div class="transform text-xl group-hover:underline">Start a game</div>
    </button>
    """
  end

  def github(assigns) do
    ~H"""
    <%= link to: "https://github.com/weizhengliu/card", class: "group mt-4" do %>
      <div class="bg-gray-300 border-2 border-white group-hover:border-gray-300 w-20 h-6 rounded-xl transform skew-x-12 -rotate-6 translate-y-7 translate-x-4"></div>
      <div class="transform text-lg group-hover:underline">Source code</div>
    <% end %>
    """
  end

  def handle_event("start_game", _params, socket) do
    room = Card.Room.new()

    {:noreply, push_redirect(socket, to: Routes.game_invite_path(socket, :host, room.id))}
  end
end

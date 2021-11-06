defmodule CardWeb.ReadyComponent do
  use CardWeb, :live_component

  def handle_event("ready", _params, %{assigns: %{player: player, room: room}} = socket) do
    Card.Room.update(room.id, Map.replace(room, :"#{player}_ready", true))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col p-4 text-center mt-8">
      <%= render_slot(@title) %>
      <div class="flex justify-between mt-2 w-60">
        <.ready_status player={is_you("Host", @player)} ready={@room.host_ready}/>
        <.ready_status player={is_you("Guest", @player)} ready={@room.guest_ready}/>
      </div>
      <%= unless Map.get(@room, :"#{@player}_ready") do %>
        <div class="flex justify-between w-44 mx-auto mt-8">
          <div class="text-lg text-center">Are you ready?</div>
          <button phx-click="ready" phx-target={@myself} class="ml-2 h-8 group">
            <div class="border-2 border-white group-hover:border-green-300 bg-green-300 w-10 h-12 rounded-xl transform skew-x-12 -rotate-45 translate-x-1 translate-y-2"></div>
            <div class="transform -translate-y-7 text-xl group-hover:underline">Yes!</div>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  defp is_you("Host", :host), do: "You"
  defp is_you("Guest", :guest), do: "You"
  defp is_you(name, _player), do: name

  def ready_status(assigns) do
    ~H"""
    <div class="flex">
      <%= @player %>:
      <div class={"ml-8 #{if @ready, do: "bg-green-300", else: "bg-red-300"} w-6 h-6 rounded-3xl transform -skew-x-3 rotate-12"}></div>
    </div>
    """
  end
end

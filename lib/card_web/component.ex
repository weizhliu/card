defmodule CardWeb.Component do
  use Phoenix.Component

  def logo(assigns) do
    ~H"""
    <header class="text-blue-500 m-4">
      <a href="/" class="text-5xl font-serif">
        🀆 CardyTotala
      </a>
    </header>
    """
  end

  def card(%{name: :fold} = assigns) do
    ~H"""
    <div class="border border-gray-200 rounded-lg p-0.5 w-14 h-22 m-1 shadow">
      <div class="border-2 p-0.5 border-blue-500 rounded-md flex justify-center items-center w-full h-full">
        <div class="bg-blue-300 rounded w-full h-full">
        </div>
      </div>
    </div>
    """
  end

  def card(assigns) do
    ~H"""
    <div class="border border-gray-200 rounded-lg p-0.5 w-14 h-22 m-1 shadow">
      <div class="border-2 border-blue-500 rounded-md flex justify-center items-center w-full h-full">
        <div class="text-xl font-bold text-blue-500">
          <%= card_name(@name) %>
        </div>
      </div>
    </div>
    """
  end

  defp card_name(:reverse), do: "Rev"
  defp card_name(name), do: name
end

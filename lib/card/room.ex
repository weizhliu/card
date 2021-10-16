defmodule Card.Room do
  defstruct id: nil, game: nil, game_pid: nil, host_ready: false, guest_ready: false

  def subscribe(id) do
    Phoenix.PubSub.subscribe(Card.PubSub, "invite" <> id)
  end

  def broadcast(id, room) do
    Phoenix.PubSub.broadcast(Card.PubSub, "invite" <> id, room)
  end

  def new(attrs \\ %{}) do
    room = struct(Card.Room, Enum.into(attrs, %{id: random_id()}))
    :ets.insert_new(:rooms, {room.id, room})
    room
  end

  def get(id) do
    case :ets.lookup(:rooms, id) do
      [{_, room}] -> room
      _ -> nil
    end
  end

  def update(id, room) do
    :ets.insert(:rooms, {id, room})
    broadcast(room.id, room)
  end

  defp random_id(), do: :crypto.strong_rand_bytes(9) |> Base.url_encode64()
end

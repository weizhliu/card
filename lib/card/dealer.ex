defmodule Card.Dealer do
  use GenServer

  def init(_) do
    {:ok, []}
  end

  def handle_call(id, _from, games) do
    case :ets.lookup(:games, id) do
      [{^id, pid}] ->
        {:reply, pid, games}

      [] ->
        {:ok, pid} = Card.Game.start(id)
        :ets.insert(:games, {id, pid})
        {:reply, pid, [id | games]}
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: :dealer)
  end

  def find_or_create_game(id) do
    GenServer.call(:dealer, id)
  end
end

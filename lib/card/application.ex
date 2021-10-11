defmodule Card.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      CardWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Card.PubSub},
      # Start the Endpoint (http/https)
      CardWeb.Endpoint,
      # Start a worker by calling: Card.Worker.start_link(arg)
      # {Card.Worker, arg}
      Card.Dealer
    ]

    # 建立 rooms 與 games table 給大家用
    :ets.new(:rooms, [:set, :public, :named_table])
    :ets.new(:games, [:set, :public, :named_table])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Card.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

defmodule Card.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CardWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:card, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Card.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Card.Finch},
      # Start a worker by calling: Card.Worker.start_link(arg)
      # {Card.Worker, arg},
      # Start to serve requests, typically the last entry
      CardWeb.Endpoint,
      Card.Dealer
    ]

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

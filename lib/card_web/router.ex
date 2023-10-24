defmodule CardWeb.Router do
  use CardWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CardWeb do
    pipe_through :browser

    live "/", PageLive.Index, :index
    live "/:id/host/invite", GameLive.Invite, :host
    live "/:id/guest/invite", GameLive.Invite, :guest
    live "/:id/host", GameLive.Game, :host
    live "/:id/guest", GameLive.Game, :guest
  end

  # Other scopes may use custom stacks.
  # scope "/api", CardWeb do
  #   pipe_through :api
  # end
end

import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :card, CardWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "rBPSwp+FbqcBA+5cUrp0dNYPKwk/0+7uaHv+OsllVa/nPNNAjcwV5e7hFgt31bcd",
  server: false

# In test we don't send emails.
config :card, Card.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

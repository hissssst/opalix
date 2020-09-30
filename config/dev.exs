import Config

config :opalix, :connection_pool,
  hostname: "localhost",
  port: 8181,
  scheme: :http,
  size: 10

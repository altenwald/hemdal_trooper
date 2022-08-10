# This configuration is intended only for test purposes
import Config

# Print only warnings and errors during test
config :logger, level: :debug

config :hemdal,
  config_module: Hemdal.Config.Backend.Env

config :hemdal, Hemdal.Config, []

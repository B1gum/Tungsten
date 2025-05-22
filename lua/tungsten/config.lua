-- config.lua
-- Defines default user configurations
----------------------------------------------------------------------------------

local config = {
  wolfram_path = "wolframscript",
  numeric_mode = false,
  debug = false,
  cache_enabled = true,
  domains = { "arithmetic", "calculus", "linear_algebra" },
  wolfram_timeout_ms = 10000,
}


return config

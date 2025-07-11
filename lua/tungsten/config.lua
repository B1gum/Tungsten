-- config.lua
-- Defines default user configurations
----------------------------------------------------------------------------------

local config = {
  wolfram_path = "wolframscript",
  numeric_mode = false,
  debug = false,
  cache_enabled = true,
  cache_max_entries = 100,
  cache_ttl = 3600,
  domains = { "arithmetic", "calculus", "linear_algebra", "differential_equations" },
  wolfram_timeout_ms = 30000,
  persistent_variable_assignment_operator = ":=",
}


return config

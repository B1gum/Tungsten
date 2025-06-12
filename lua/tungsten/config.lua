-- config.lua
-- Defines default user configurations
----------------------------------------------------------------------------------

local config = {
  wolfram_path = "wolframscript",
  numeric_mode = false,
  debug = true,
  cache_enabled = true,
  domains = { "arithmetic", "calculus", "linear_algebra", "differential_equations" },
  wolfram_timeout_ms = 30000,
  persistent_variable_assignment_operator = ":=",
}


return config

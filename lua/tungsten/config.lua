-- config.lua
-- Defines default user configurations
----------------------------------------------------------------------------------

local config = {
  wolfram_path = "wolframscript",
  numeric_mode = false,
  debug = false,
  log_level = "INFO",
  cache_enabled = true,
  cache_max_entries = 100,
  cache_ttl = 3600,
  domains = { "arithmetic", "calculus", "linear_algebra", "differential_equations" },
  user_domains_path = nil,
  wolfram_timeout_ms = 30000,
  persistent_variable_assignment_operator = ":=",
  wolfram_function_mappings = {
    sin = "Sin", cos = "Cos", tan = "Tan", arcsin = "ArcSin", arccos = "ArcCos",
    arctan = "ArcTan", sinh = "Sinh", cosh = "Cosh", tanh = "Tanh", arsinh = "ArcSinh",
    arcosh = "ArcCosh", artanh = "ArcTanh", log = "Log", ln = "Log", log10 = "Log10",
    exp = "Exp", u = "HeavisideTheta",
  },
}


return config

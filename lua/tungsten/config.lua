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
	enable_default_mappings = true,
	domains = { "arithmetic", "calculus", "linear_algebra", "differential_equations" },
	process_timeout_ms = 30000,
	result_separator = " = ",
	result_display = "insert",
	max_jobs = 5,
	persistent_variable_assignment_operator = ":=",
	backend = "wolfram",
	backend_opts = {},
	wolfram_function_mappings = {
		sin = "Sin",
		cos = "Cos",
		tan = "Tan",
		arcsin = "ArcSin",
		arccos = "ArcCos",
		arctan = "ArcTan",
		sinh = "Sinh",
		cosh = "Cosh",
		tanh = "Tanh",
		arsinh = "ArcSinh",
		arcosh = "ArcCosh",
		artanh = "ArcTanh",
		log = "Log",
		ln = "Log",
		log10 = "Log10",
		exp = "Exp",
		u = "HeavisideTheta",
	},
	hooks = {},
}

return config

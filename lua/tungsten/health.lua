local M = {}

local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

local function check_python_environment()
	start("Python Environment (for Python backend)")

	if vim.fn.executable("python3") == 1 then
		ok("`python3` executable found.")

		local required_pkgs = { "sympy", "matplotlib" }
		local cmd = string.format('python3 -c "import %s"', table.concat(required_pkgs, ", "))

		vim.fn.system(cmd)

		if vim.v.shell_error == 0 then
			ok(string.format("Required Python packages found: %s", table.concat(required_pkgs, ", ")))
		else
			warn("Missing one or more required Python packages (" .. table.concat(required_pkgs, ", ") .. ").", {
				"Run `pip install sympy matplotlib` or ensure your virtual environment is active.",
			})
		end
	else
		warn("`python3` executable not found.", {
			"If you plan to use the Python backend, ensure `python3` is installed and in your PATH.",
		})
	end
end

local function check_wolfram_environment(config)
	start("Wolfram Environment (for Wolfram backend)")

	local ws_path = config.backend_opts.wolfram and config.backend_opts.wolfram.wolfram_path or "wolframscript"

	if vim.fn.executable(ws_path) == 1 then
		ok(string.format("Wolfram executable found: `%s`", ws_path))
	else
		warn(string.format("Wolfram executable not found: `%s`", ws_path), {
			"If you plan to use the Wolfram backend, ensure it is installed and in your PATH.",
			"Alternatively, update `backend_opts.wolfram.wolfram_path` in your Tungsten config.",
		})
	end
end

function M.check()
	start("Tungsten Core")

	if vim.fn.has("nvim-0.9.0") == 1 then
		ok("Neovim version is compatible (>= 0.9.0).")
	else
		error("Tungsten requires Neovim >= 0.9.0.", {
			"Please upgrade your Neovim installation.",
		})
	end

	start("Configuration Sanity")
	local config_ok, config = pcall(require, "tungsten.config")
	if config_ok and type(config) == "table" then
		ok("Tungsten configuration loaded successfully.")
		info(string.format("Active computation backend: `%s`", config.backend or "unknown"))
		info(string.format("Active plotting backend: `%s`", config.plotting and config.plotting.backend or "unknown"))

		if config.backend == "python" or (config.plotting and config.plotting.backend == "python") then
			check_python_environment()
		end

		if config.backend == "wolfram" or (config.plotting and config.plotting.backend == "wolfram") then
			check_wolfram_environment(config)
		end
	else
		error("Failed to load Tungsten configuration.", {
			"Check your `tungsten.setup()` call for syntax errors or invalid options.",
		})
	end
end

return M

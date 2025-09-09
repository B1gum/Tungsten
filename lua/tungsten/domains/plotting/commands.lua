local workflow = require("tungsten.plot.workflow")
local health = require("tungsten.domains.plotting.health")
local job_manager = require("tungsten.domains.plotting.job_manager")
local selection = require("tungsten.util.selection")
local error_handler = require("tungsten.util.error_handler")

local M = {}

function M.simple_plot_command()
	local text = selection.get_visual_selection()
	if not text or text:match("^%s*$") then
		error_handler.notify_error("TungstenPlot", "Simple plot requires a visual selection.")
		return
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	workflow.run_simple(text)
end

function M.advanced_plot_command()
	workflow.run_advanced()
end

function M.check_dependencies_command()
	local report = health.check_dependencies()

	local required_versions = {
		wolframscript = "13.0",
		python = "3.10",
		numpy = "1.23",
		sympy = "1.12",
		matplotlib = "3.6",
	}

	local backends = {
		{ name = "Wolfram", deps = { "wolframscript" } },
		{ name = "Python", deps = { "python", "numpy", "sympy", "matplotlib" } },
	}

	local lines = {}
	for i, backend in ipairs(backends) do
		table.insert(lines, string.format("%d. %s", i, backend.name))
		for _, dep in ipairs(backend.deps) do
			local info = report[dep] or {}

			local detected = "none"
			if info.version then
				detected = info.version
			elseif info.message then
				detected = info.message:match("found ([%d%.]+)") or "none"
			end

			if info.ok then
				table.insert(lines, string.format("  - %s: %s ✔", dep, detected))
			else
				local hint
				if dep == "wolframscript" then
					hint = string.format("install Wolfram Language ≥%s", required_versions[dep])
				elseif dep == "python" then
					hint = string.format("install Python ≥%s", required_versions[dep])
				else
					hint = string.format("install %s ≥%s via pip", dep, required_versions[dep])
				end
				table.insert(lines, string.format("  - %s: %s ✘ (%s)", dep, detected, hint))
			end
		end
	end

	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Tungsten PlotCheck" })
	if job_manager.reset_deps_check then
		job_manager.reset_deps_check()
	end
end

function M.cancel_command(opts)
	local id
	if opts and opts.args ~= "" then
		id = tonumber(opts.args)
	else
		for jid in pairs(job_manager.active_jobs) do
			if not id or jid > id then
				id = jid
			end
		end
	end
	if id then
		job_manager.cancel(id)
	else
		vim.notify("No active plot jobs", vim.log.levels.INFO, { title = "TungstenPlotCancel" })
	end
end

function M.cancel_all_command()
	job_manager.cancel_all()
end

M.commands = {
	{
		name = "TungstenPlot",
		func = M.simple_plot_command,
		opts = { range = true, desc = "Generate a plot from the selection" },
	},
	{
		name = "TungstenPlotAdvanced",
		func = M.advanced_plot_command,
		opts = { desc = "Open advanced plotting configuration" },
	},
	{
		name = "TungstenPlotCancel",
		func = M.cancel_command,
		opts = { nargs = "?", desc = "Cancel a running plot job" },
	},
	{
		name = "TungstenPlotCancelAll",
		func = M.cancel_all_command,
		opts = { desc = "Cancel all running plot jobs" },
	},
	{
		name = "TungstenPlotCheck",
		func = M.check_dependencies_command,
		opts = { desc = "Check plotting dependencies" },
	},
}

return M

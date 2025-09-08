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
	local lines = {
		string.format("wolframscript: %s", report.wolframscript and "OK" or "missing"),
		string.format("python: %s", report.python and "OK" or "missing"),
		string.format("matplotlib: %s", report.matplotlib and "OK" or "missing"),
		string.format("sympy: %s", report.sympy and "OK" or "missing"),
	}
	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Tungsten PlotCheck" })
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

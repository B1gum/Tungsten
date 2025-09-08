local core = require("tungsten.core.plotting")
local error_handler = require("tungsten.util.error_handler")
local state = require("tungsten.state")
local config = require("tungsten.config")
local async = require("tungsten.util.async")
local io_util = require("rungsten.util.io")

local M = {}

local function parse_definitions(input)
	local defs = {}
	if not input or input == "" then
		return defs
	end
	for line in input:gmatch("[^\n]+") do
		local lhs, rhs = line:match("^%s*(.-)%s*:?=%s*(.-)%s*$")
		if lhs and rhs and lhs ~= "" and rhs ~= "" then
			defs[lhs] = { latex = rhs }
		end
	end
	return defs
end

function M.handle_undefined_symbols(opts, callback)
	opts = opts or {}
	local definitions = {}
	for name, val in pairs(state.persistent_variables or {}) do
		definitions[name] = { latex = val }
	end

	local _, undefined = core.get_undefined_symbols(opts)
	undefined = undefined or {}
	local to_define = {}
	for _, sym in ipairs(undefined) do
		if not definitions[sym.name] then
			table.insert(to_define, sym)
		end
	end

	if #to_define == 0 then
		if next(opts) ~= nil then
			opts.definitions = definitions
			if callback then
				callback(opts)
			end
		else
			if callback then
				callback(definitions)
			end
		end
		return
	end

	local lines = {}
	for _, sym in ipairs(to_define) do
		lines[#lines + 1] = sym.name .. " = "
	end
	local default = table.concat(lines, "\n")

	vim.ui.input({ prompt = "Define symbols for plot:", default = default }, function(user_input)
		local parsed = parse_definitions(user_input)
		for name, def in pairs(parsed) do
			definitions[name] = def
		end
		if next(opts) ~= nil then
			opts.definitions = definitions
			if callback then
				callback(opts)
			end
		else
			if callback then
				callback(definitions)
			end
		end
	end)
end

function M.start_plot_workflow(opts)
	opts = opts or {}
	M.handle_undefined_symbols(opts, function(final_opts)
		final_opts.on_error = function(code, msg)
			error_handler.notify_error("Plot Error", string.format("%s: %s", code, msg))
		end
		core.initiate_plot(final_opts)
	end)
end

function M.insert_snippet(bufnr, selection_end_line, plot_path)
	local width = (config.plotting or {}).snippet_width or "0.8\\linewidth"
	local _, line = io_util.find_math_block_end(bufnr, selection_end_line)
	line = line or selection_end_line
	local snippet = string.format("\\includegraphics[width=%s]{%s}", width, plot_path)
	vim.api.nvim_buf_set_lines(bufnr, line, line, false, { snippet })
end

function M.handle_output(plot_path)
	local cfg = config.plotting or {}
	if cfg.outputmode ~= nil and cfg.outputmode ~= "viewer" then
		return
	end
	local cmd
	if plot_path:match("%.pdf$") then
		cmd = cfg.viewer_cmd_pdf
	else
		cmd = cfg.viewer_cmd_png
	end
	if not cmd or cmd == "" then
		cmd = vim.fn.has("macunix") == 1 and "open" or "xdg-open"
	end
	async.run_job({ cmd, plot_path }, {
		on_exit = function(code, _out, err)
			if code ~= 0 then
				error_handler.notify_error("Plot Viewer", "E_VIEWER_FAILED: " .. (err or ""))
			end
		end,
	})
end

local function build_default_lines(opts)
	opts = opts or {}
	local classification = opts.classification or {}
	local lines = {}
	lines[#lines + 1] = "Form: " .. (classification.form or "explicit")
	local dim = classification.dim or 2
	if dim >= 1 then
		lines[#lines + 1] = "X-range:"
	end
	if dim >= 2 then
		lines[#lines + 1] = "Y-range:"
	end
	if dim >= 3 then
		lines[#lines + 1] = "Z-range:"
	end
	lines[#lines + 1] = "Grid: on"
	if dim >= 1 then
		lines[#lines + 1] = "X-scale: linear"
	end
	if dim >= 2 then
		lines[#lines + 1] = "Y-scale: linear"
	end
	if dim >= 3 then
		lines[#lines + 1] = "Z-scale: linear"
	end
	lines[#lines + 1] = ""
	if opts.series then
		for i, s in ipairs(opts.series) do
			lines[#lines + 1] = string.format("--- Series %d: %s ---", i, s.ast or "")
			lines[#lines + 1] = "Label:"
			lines[#lines + 1] = "Color:"
			lines[#lines + 1] = ""
		end
	end
	return lines
end

function M.open_advanced_config(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_create_buf(false, true)
	local lines = build_default_lines(opts)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_open_win(bufnr, true, { relative = "editor", width = 60, height = #lines, row = 1, col = 1 })
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = bufnr,
		callback = function()
			core.initiate_plot(opts)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", { buffer = bufnr, callback = function() end })
end

function M.build_final_opts_from_classification(classification)
	local final = vim.deepcopy(classification or {})
	final.series = {}
	local src_series = (classification and classification.series) or {}
	local multi = #src_series > 1
	for i, s in ipairs(src_series) do
		final.series[i] = vim.deepcopy(s)
		if multi and (not final.series[i].label or final.series[i].label == "") then
			final.series[i].label = string.format("Series %d", i)
		end
	end
	if #final.series > 1 then
		final.legend_auto = true
	elseif #final.series == 1 then
		local lbl = final.series[1].label
		final.legend_auto = lbl ~= nil and lbl ~= ""
	else
		final.legend_auto = false
	end
	return final
end

return M

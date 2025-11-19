local parser = require("tungsten.core.parser")
local ast = require("tungsten.core.ast")
local classification = require("tungsten.domains.plotting.classification")
local options_builder = require("tungsten.domains.plotting.options_builder")
local plot_io = require("tungsten.domains.plotting.io")
local job_manager = require("tungsten.domains.plotting.job_manager")
local error_handler = require("tungsten.util.error_handler")
local selection = require("tungsten.util.selection")
local plotting_ui = require("tungsten.ui.plotting")

local M = {}

local DEFAULT_ERROR_CODE = error_handler.E_BAD_OPTS or "E_BAD_OPTS"
local BACKEND_FAILURE_CODE = error_handler.E_BACKEND_CRASH or "E_BACKEND_CRASH"

local function normalize_error(err)
	if err == nil then
		return nil, nil
	end
	if type(err) ~= "table" then
		return nil, tostring(err)
	end
	local code = err.code
	local message = err.message or err.msg or err.error or err.reason
	if message ~= nil then
		message = tostring(message)
	end
	return code, message
end

local function notify_error(err, pos, input, fallback_code)
	local code, message = normalize_error(err)
	local selected_code = code or fallback_code or DEFAULT_ERROR_CODE
	local suffix = message
	if suffix ~= nil and suffix ~= "" then
		suffix = tostring(suffix)
	else
		suffix = nil
	end
	error_handler.notify_error("TungstenPlot", selected_code, pos, input, suffix)
end

local function get_selection_range()
	local bufnr = vim.api.nvim_get_current_buf()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	if start_pos[1] == 0 or end_pos[1] == 0 then
		return bufnr, 0, 0, 0, 0
	end

	if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
		start_pos, end_pos = end_pos, start_pos
	end

	local start_line = math.max(start_pos[2] - 1, 0)
	local end_line = math.max(end_pos[2] - 1, 0)
	local start_col = math.max(start_pos[3] - 1, 0)
	local end_col = math.max(end_pos[3], 0)

	local line = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1] or ""
	if end_col > #line then
		end_col = #line
	end

	local mode = vim.fn.mode(1)
	if mode == "V" then
		start_col = 0
		end_col = 0
		end_line = end_line + 1
	end

	return bufnr, start_line, start_col, end_line, end_col
end

local function merge_classifications(nodes)
	local combined = { series = {} }
	for _, node in ipairs(nodes) do
		local res, err = classification.analyze(node, { simple_mode = true, mode = "simple" })
		if not res then
			return nil, err
		end

		if combined.dim and res.dim and combined.dim ~= res.dim then
			return nil,
				{
					code = error_handler.E_UNSUPPORTED_DIM,
					message = "Select expressions of the same dimension before plotting.",
				}
		end
		if combined.form and res.form and combined.form ~= res.form then
			return nil,
				{
					code = error_handler.E_MIXED_COORD_SYS,
					message = "Use the same coordinate system for all expressions before plotting.",
				}
		end

		for key, value in pairs(res) do
			if key == "series" then
				for _, series_entry in ipairs(value or {}) do
					combined.series[#combined.series + 1] = vim.deepcopy(series_entry)
				end
			elseif combined[key] == nil and value ~= nil then
				combined[key] = value
			end
		end
	end

	if not combined.dim or not combined.form or #combined.series == 0 then
		return nil,
			{
				code = error_handler.E_NO_PLOTTABLE_SERIES,
				message = "Select an expression with a plottable series so Tungsten can detect the dimension and coordinate form.",
			}
	end

	return combined
end

local function build_plot_ast(nodes)
	if #nodes == 1 then
		return nodes[1]
	elseif #nodes > 1 then
		if ast.create_sequence_node then
			return ast.create_sequence_node(nodes)
		end
	end
	return nil
end

local function capture_backend_command(plot_opts)
	local backend_name = plot_opts.backend or "wolfram"
	local ok_mod, backend_module = pcall(require, "tungsten.backends." .. backend_name)
	if not ok_mod then
		return nil, backend_module
	end

	if type(backend_module.translate_plot_error) == "function" then
		plot_opts._error_translator = backend_module.translate_plot_error
	else
		plot_opts._error_translator = nil
	end

	local plot_async = backend_module and backend_module.plot_async
	if type(plot_async) ~= "function" then
		return nil, string.format("Backend '%s' does not support plotting", backend_name)
	end

	local async = require("tungsten.util.async")
	local original = async.run_job
	local captured_cmd, captured_opts
	local backend_err

	async.run_job = function(cmd, opts)
		captured_cmd = vim.deepcopy(cmd)
		captured_opts = opts
		return {}
	end

	local ok_call, call_err = pcall(plot_async, vim.deepcopy(plot_opts), function(err)
		backend_err = backend_err or err
	end)

	async.run_job = original

	if not ok_call then
		return nil, call_err
	end
	if backend_err then
		return nil, backend_err
	end
	if not captured_cmd then
		return nil, "Failed to prepare plot command"
	end

	return captured_cmd, captured_opts
end

function M.run_simple(text)
	if type(text) ~= "string" then
		text = ""
	else
		text = text:gsub("^%s+", ""):gsub("%s+$", "")
	end

	if text == "" then
		notify_error("Simple plot requires an expression")
		return
	end

	local ok_parse, parsed, err_msg, err_pos, err_input = pcall(parser.parse, text, { simple_mode = true })
	if not ok_parse then
		notify_error(parsed)
		return
	end
	if not parsed or not parsed.series or #parsed.series == 0 then
		notify_error(err_msg or "Unable to parse selection", err_pos, err_input)
		return
	end

	local classification_data, classify_err = merge_classifications(parsed.series)
	if not classification_data then
		notify_error(classify_err)
		return
	end

	local plot_opts = options_builder.build(classification_data, {})
	plot_opts.series = plot_opts.series or classification_data.series
	plot_opts.expression = text

	local bufnr, start_line, start_col, end_line, end_col = get_selection_range()
	plot_opts.bufnr = bufnr
	plot_opts.start_line = start_line
	plot_opts.start_col = start_col
	plot_opts.end_line = end_line
	plot_opts.end_col = end_col

	local buf_path = vim.api.nvim_buf_get_name(bufnr)
	local tex_root, tex_err = plot_io.find_tex_root(buf_path)
	if not tex_root then
		notify_error(tex_err)
		return
	end

	local output_dir, output_err, uses_graphicspath = plot_io.get_output_directory(tex_root)
	if not output_dir then
		notify_error(output_err)
		return
	end

	local plot_ast = build_plot_ast(parsed.series)

	local function continue_with_definitions(symbol_opts)
		if type(symbol_opts) ~= "table" then
			symbol_opts = {}
		end
		local definitions = symbol_opts.definitions
		if type(definitions) ~= "table" then
			definitions = {}
		end

		plot_opts.definitions = definitions

		local out_path = plot_io.get_final_path(output_dir, plot_opts, {
			ast = plot_ast,
			var_defs = definitions,
		})

		if not out_path or out_path == "" then
			notify_error("Unable to determine output path")
			return
		end

		plot_opts.out_path = out_path
		plot_opts.uses_graphicspath = uses_graphicspath
		plot_opts.tex_root = tex_root

		local command, command_opts = capture_backend_command(plot_opts)
		if not command then
			notify_error(command_opts, nil, nil, BACKEND_FAILURE_CODE)
			return
		end

		for i = 1, #command do
			plot_opts[i] = command[i]
		end

		if command_opts and command_opts.timeout then
			plot_opts.timeout_ms = command_opts.timeout
		end

		job_manager.submit(plot_opts)
	end

	plotting_ui.handle_undefined_symbols({
		expression = text,
		ast = plot_ast,
	}, continue_with_definitions)
end

function M.run_advanced()
	local text = selection.get_visual_selection()
	if type(text) ~= "string" then
		text = ""
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")

	if text == "" then
		notify_error("Advanced plot requires an expression")
		return
	end

	local ok_parse, parsed, err_msg, err_pos, err_input = pcall(parser.parse, text, { simple_mode = true })
	if not ok_parse then
		notify_error(parsed)
		return
	end
	if not parsed or not parsed.series or #parsed.series == 0 then
		notify_error(err_msg or "Unable to parse selection", err_pos, err_input)
		return
	end

	local classification_data, classify_err = merge_classifications(parsed.series)
	if not classification_data then
		notify_error(classify_err)
		return
	end

	local plot_ast = build_plot_ast(parsed.series)

	local bufnr, start_line, start_col, end_line, end_col = get_selection_range()

	local function submit_advanced(final_opts)
		final_opts = final_opts or {}
		final_opts.on_submit = nil

		local target_bufnr = final_opts.bufnr or bufnr
		if not target_bufnr or target_bufnr == 0 then
			target_bufnr = vim.api.nvim_get_current_buf()
			final_opts.bufnr = target_bufnr
		end

		final_opts.expression = final_opts.expression or text
		final_opts.ast = final_opts.ast or plot_ast
		final_opts.start_line = final_opts.start_line or start_line
		final_opts.start_col = final_opts.start_col or start_col
		final_opts.end_line = final_opts.end_line or end_line
		final_opts.end_col = final_opts.end_col or end_col

		local buf_path = vim.api.nvim_buf_get_name(target_bufnr)
		local tex_root, tex_err = plot_io.find_tex_root(buf_path)
		if not tex_root then
			notify_error(tex_err)
			return
		end

		local output_dir, output_err, uses_graphicspath = plot_io.get_output_directory(tex_root)
		if not output_dir then
			notify_error(output_err)
			return
		end

		local out_path = plot_io.get_final_path(output_dir, final_opts, {
			ast = final_opts.ast,
			var_defs = final_opts.definitions,
		})

		if not out_path or out_path == "" then
			notify_error("Unable to determine output path")
			return
		end

		final_opts.out_path = out_path
		final_opts.uses_graphicspath = uses_graphicspath
		final_opts.tex_root = tex_root

		local function submit_job()
			local command, command_opts = capture_backend_command(final_opts)
			if not command then
				notify_error(command_opts, nil, nil, BACKEND_FAILURE_CODE)
				return
			end

			for i = 1, #command do
				final_opts[i] = command[i]
			end

			if command_opts and command_opts.timeout then
				final_opts.timeout_ms = command_opts.timeout
			end

			job_manager.submit(final_opts)
		end

		submit_job()
	end

	plotting_ui.open_advanced_config({
		expression = text,
		classification = classification_data,
		series = vim.deepcopy(classification_data.series),
		parsed_series = vim.deepcopy(parsed.series),
		ast = plot_ast,
		bufnr = bufnr,
		start_line = start_line,
		start_col = start_col,
		end_line = end_line,
		end_col = end_col,
		on_submit = submit_advanced,
	})
end

return M

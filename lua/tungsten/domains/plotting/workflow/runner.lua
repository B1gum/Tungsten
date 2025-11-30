local parser = require("tungsten.core.parser")
local ast = require("tungsten.core.ast")
local options_builder = require("tungsten.domains.plotting.options_builder")
local job_manager = require("tungsten.domains.plotting.job_manager")
local error_handler = require("tungsten.util.error_handler")
local output_metadata = require("tungsten.util.plotting.output_metadata")
local plotting_ui = require("tungsten.ui.plotting")
local backend_command = require("tungsten.domains.plotting.workflow.backend_command")
local classification_merge = require("tungsten.domains.plotting.workflow.classification_merge")
local selection_utils = require("tungsten.domains.plotting.workflow.selection")
local path_resolver = require("tungsten.util.plotting.path_resolver")

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

	local classification_data, classify_err = classification_merge.merge(parsed.series)
	if not classification_data then
		notify_error(classify_err)
		return
	end

	local plot_opts = options_builder.build(classification_data, {})
	plot_opts.series = plot_opts.series or classification_data.series
	plot_opts.expression = text

	local bufnr, start_line, start_col, end_line, end_col = selection_utils.get_selection_range()
	plot_opts.bufnr = bufnr
	plot_opts.start_line = start_line
	plot_opts.start_col = start_col
	plot_opts.end_line = end_line
	plot_opts.end_col = end_col

	local tex_root, output_dir, uses_graphicspath, path_err = path_resolver.resolve_paths(bufnr)
	if not tex_root then
		notify_error(path_err)
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

                local out_path, out_err = output_metadata.assign(output_dir, plot_opts, {
                        ast = plot_ast,
                        definitions = definitions,
                        uses_graphicspath = uses_graphicspath,
                        tex_root = tex_root,
                })

                if not out_path then
                        notify_error(out_err)
                        return
                end

		local command, command_opts = backend_command.capture(plot_opts)
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
	local text = selection_utils.get_trimmed_visual_selection()

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

	local classification_data, classify_err = classification_merge.merge(parsed.series)
	if not classification_data then
		notify_error(classify_err)
		return
	end

	if classification_data.form == "parametric" then
		notify_error({
			code = error_handler.E_UNSUPPORTED_FORM,
			message = "Use :TungstenPlotParametric for parametric plots.",
		})
		return
	end

	local plot_ast = build_plot_ast(parsed.series)

	local bufnr, start_line, start_col, end_line, end_col = selection_utils.get_selection_range()

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

		local tex_root, output_dir, uses_graphicspath, path_err = path_resolver.resolve_paths(target_bufnr)
		if not tex_root then
			notify_error(path_err)
			return
		end

                local out_path, out_err = output_metadata.assign(output_dir, final_opts, {
                        uses_graphicspath = uses_graphicspath,
                        tex_root = tex_root,
                })

                if not out_path then
                        notify_error(out_err)
                        return
                end

		local function submit_job()
			local command, command_opts = backend_command.capture(final_opts)
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
		allowed_forms = { explicit = true, implicit = true, polar = true },
		on_submit = submit_advanced,
	})
end

function M.run_parametric()
	local text = selection_utils.get_trimmed_visual_selection()

	if text == "" then
		notify_error("Parametric plot requires an expression")
		return
	end

	local parse_opts = { mode = "advanced", form = "parametric" }
	local ok_parse, parsed, err_msg, err_pos, err_input = pcall(parser.parse, text, parse_opts)
	if not ok_parse then
		notify_error(parsed)
		return
	end
	if not parsed or not parsed.series or #parsed.series == 0 then
		notify_error(err_msg or "Unable to parse selection", err_pos, err_input)
		return
	end

	local classification_data, classify_err = classification_merge.merge(parsed.series, parse_opts)
	if not classification_data then
		notify_error(classify_err)
		return
	end

	local plot_ast = build_plot_ast(parsed.series)

	local bufnr, start_line, start_col, end_line, end_col = selection_utils.get_selection_range()

	local function submit_parametric(final_opts)
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

		local tex_root, output_dir, uses_graphicspath, path_err = path_resolver.resolve_paths(target_bufnr)
		if not tex_root then
			notify_error(path_err)
			return
		end

                local out_path, out_err = output_metadata.assign(output_dir, final_opts, {
                        uses_graphicspath = uses_graphicspath,
                        tex_root = tex_root,
                })

                if not out_path then
                        notify_error(out_err)
                        return
                end

		local function submit_job()
			local command, command_opts = backend_command.capture(final_opts)
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
		allowed_forms = { parametric = true },
		on_submit = submit_parametric,
	})
end

return M

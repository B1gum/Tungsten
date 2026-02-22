local render = require("tungsten.core.render")

local BaseExecutor = {}

local function get_async()
	return require("tungsten.util.async")
end

local function get_logger()
	return require("tungsten.util.logger")
end

local function clone_opts(opts, extra)
	local merged = {}
	if opts then
		for key, value in pairs(opts) do
			merged[key] = value
		end
	end
	if extra then
		for key, value in pairs(extra) do
			merged[key] = value
		end
	end
	return merged
end

local function get_error_label(executor)
	return executor.display_name or "backend"
end

local function format_convert_error(executor, detail)
	return ("Error converting AST to %s code: %s"):format(get_error_label(executor), tostring(detail))
end

local function format_exit_error(executor, exit_code)
	if executor.exit_error then
		return executor.exit_error(exit_code)
	end
	return ("%s interpreter exited with code %d"):format(get_error_label(executor), exit_code)
end

local function format_timeout_error(executor, timeout_ms)
	local label = get_error_label(executor)
	if timeout_ms and tonumber(timeout_ms) then
		return string.format("E_TIMEOUT: %s evaluation timed out after %d ms.", label, timeout_ms)
	end
	return string.format("E_TIMEOUT: %s evaluation timed out.", label)
end

local function format_cancel_error(executor)
	return string.format("E_CANCELLED: %s evaluation cancelled.", get_error_label(executor))
end

local function resolve_timeout_ms(opts, config)
	if opts then
		if opts.timeout ~= nil then
			return opts.timeout
		end
		if opts.timeout_ms ~= nil then
			return opts.timeout_ms
		end
	end
	if config then
		if config.timeout_ms ~= nil then
			return config.timeout_ms
		end
		if config.process_timeout_ms ~= nil then
			return config.process_timeout_ms
		end
	end
	return nil
end

function BaseExecutor.evaluate_async(executor, ast, opts, callback)
	assert(type(callback) == "function", "evaluate_async expects callback")

	opts = opts or {}
	local show_spinner = opts.show_spinner
	if show_spinner == nil then
		show_spinner = true
	end
	local cache_key = opts.cache_key

	local ok, code = pcall(executor.ast_to_code, ast)
	if not ok or not code then
		callback(nil, format_convert_error(executor, code))
		return
	end

	if opts.code then
		code = opts.code
	end

	local build_opts = clone_opts(opts, { ast = ast })
	local command_args, command_ctx = executor.build_command(code, build_opts)
	local interpreter = executor.get_interpreter_command()

	local full_command = { interpreter }
	for _, arg in ipairs(command_args or {}) do
		table.insert(full_command, arg)
	end

	get_async().run_job(full_command, {
		cache_key = cache_key,
		timeout = opts.timeout or opts.timeout_ms,
		show_spinner = show_spinner,
		spinner = opts.spinner,
		on_exit = function(exit_code, stdout, stderr, meta)
			if exit_code == 0 then
				if stderr ~= "" then
					get_logger().debug("Tungsten Debug", "Tungsten Debug (stderr): " .. stderr)
				end

				local output = stdout
				if executor.sanitize_output then
					output = executor.sanitize_output(stdout, command_ctx or build_opts)
				end
				callback(output, nil)
			else
				local err_msg
				local timed_out = (meta and meta.timed_out) or exit_code == 124
				if timed_out then
					err_msg = format_timeout_error(executor, meta and meta.timeout_ms)
				elseif exit_code == 127 then
					err_msg = executor.not_found_message or (get_error_label(executor) .. " interpreter not found.")
				elseif exit_code == -1 then
					if meta and meta.cancel_reason then
						err_msg = format_cancel_error(executor)
					else
						err_msg = executor.not_found_message or (get_error_label(executor) .. " interpreter not found.")
					end
				else
					err_msg = format_exit_error(executor, exit_code)
				end
				if stderr ~= "" then
					err_msg = err_msg .. "\nStderr: " .. stderr
				elseif stdout ~= "" then
					err_msg = err_msg .. "\nStdout (potentially error): " .. stdout
				end
				callback(nil, err_msg)
			end
		end,
	})
end

function BaseExecutor.solve_async(executor, solve_ast, opts, callback)
	assert(type(callback) == "function", "solve_async expects callback")

	opts = opts or {}
	local ok, code = pcall(executor.ast_to_code, solve_ast)
	if not ok or not code then
		callback(nil, format_convert_error(executor, code))
		return
	end

	local variables = {}
	for _, v in ipairs(solve_ast.variables or {}) do
		local ok_name, name = pcall(executor.ast_to_code, v)
		table.insert(variables, ok_name and name or tostring(v.name or ""))
	end

	local eval_opts = { code = code, cache_key = opts.cache_key }
	if executor.prepare_solve_opts then
		local extra = executor.prepare_solve_opts(solve_ast, opts)
		for key, value in pairs(extra or {}) do
			eval_opts[key] = value
		end
	end

	BaseExecutor.evaluate_async(executor, nil, eval_opts, function(result, err)
		if err then
			callback(nil, err)
			return
		end

		local parsed = executor.parse_solution(result, variables, opts)
		if parsed.ok then
			callback(parsed.formatted, nil)
		else
			callback(nil, parsed.reason or "No solution")
		end
	end)
end

function BaseExecutor.ast_to_code(executor, ast, opts)
	opts = opts or {}
	if opts.ensure_handlers then
		opts.ensure_handlers()
	end

	if not ast then
		return "Error: AST is nil"
	end
	local registry = require("tungsten.core.registry")
	local registry_handlers = registry.get_handlers()
	if next(registry_handlers) == nil then
		local label = opts.handlers_label or get_error_label(executor)
		return ("Error: No %s handlers loaded for AST conversion."):format(label)
	end

	local rendered_result = render.render(ast, registry_handlers)

	if type(rendered_result) == "table" and rendered_result.error then
		local error_message = rendered_result.message
		if rendered_result.node_type then
			error_message = error_message .. " (Node type: " .. rendered_result.node_type .. ")"
		end
		return "Error: AST rendering failed: " .. error_message
	end

	return rendered_result
end

function BaseExecutor.evaluate_persistent(executor, ast, opts, callback)
	local state = require("tungsten.state")
	local async = require("tungsten.util.async")
	local config = require("tungsten.config")

	local ok, code = pcall(executor.ast_to_code, ast)
	if not ok or not code then
		callback(nil, format_convert_error(executor, code))
		return
	end

	if opts and opts.code then
		code = opts.code
	end

	local delimiter = "__TUNGSTEN_END__"
	local formatted_input = executor.format_persistent_input(code, delimiter)
	local timeout_ms = resolve_timeout_ms(opts, config)
	local timeout_error = format_timeout_error(executor, timeout_ms)
	local cancel_error = format_cancel_error(executor)
	local show_spinner = opts.show_spinner
	if show_spinner == nil then
		show_spinner = true
	end

	if state.persistent_job and state.persistent_job.is_dead and state.persistent_job:is_dead() then
		state.persistent_job = nil
	end

	if not state.persistent_job then
		local cmd = executor.get_persistent_command()
		state.persistent_job = async.create_persistent_job(cmd, { delimiter = delimiter })

		if executor.get_persistent_init then
			local init_code = executor.get_persistent_init()
			if init_code then
				local fmt_func = executor.format_persistent_init or executor.format_persistent_input
				local formatted_init = fmt_func(init_code, delimiter)
				state.persistent_job:send(formatted_init, function(_, _) end, {
					timeout_ms = timeout_ms,
					timeout_error = timeout_error,
					cancel_error = cancel_error,
				})
			end
		end
	end

	state.persistent_job:send(formatted_input, function(output, err)
		if err then
			local job = state.persistent_job
			if job and job.is_dead and job:is_dead() and job.last_error then
				local last = tostring(job.last_error)
				if last:find("E_TIMEOUT", 1, true) then
					err = job.last_error
				end
			end
			callback(nil, err)
		else
			if executor.sanitize_persistent_output then
				output = executor.sanitize_persistent_output(output, opts)
			end
			callback(output, nil)
		end
	end, {
		show_spinner = show_spinner,
		spinner = opts.spinner,
		timeout_ms = timeout_ms,
		timeout_error = timeout_error,
		cancel_error = cancel_error,
	})
end

return BaseExecutor

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

function BaseExecutor.evaluate_async(executor, ast, opts, callback)
	assert(type(callback) == "function", "evaluate_async expects callback")

	opts = opts or {}
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
		on_exit = function(exit_code, stdout, stderr)
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
				if exit_code == -1 or exit_code == 127 then
					err_msg = executor.not_found_message or (get_error_label(executor) .. " interpreter not found.")
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

return BaseExecutor

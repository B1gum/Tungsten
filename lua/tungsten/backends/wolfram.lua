-- backends/wolfram.lua
-- Handles all interaction with the WolframEngine.
---------------------------------------------------------------------
local render = require("tungsten.core.render")
local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local manager = require("tungsten.backends.manager")

local M = {}
local handlerRegistry = {}
local renderableHandlers = {}
local handlers_initialized = false

local function _process_domain_handlers(domain_name, registry)
	local handler_module_path = "tungsten.backends.wolfram.domains." .. domain_name
	local ok, domain_module = pcall(require, handler_module_path)

	if ok and domain_module and domain_module.handlers then
		local domain_priority = registry.get_domain_priority(domain_name)
		logger.debug(
			"Tungsten Debug",
			("Wolfram Backend: Successfully loaded handlers module from %s for domain %s (Priority: %d)"):format(
				handler_module_path,
				domain_name,
				domain_priority
			)
		)

		for node_type, handler_func in pairs(domain_module.handlers) do
			if handlerRegistry[node_type] then
				local existing_handler_info = handlerRegistry[node_type]
				if domain_priority > existing_handler_info.domain_priority then
					logger.debug(
						"Tungsten Backend",
						("Wolfram Backend: Handler for node type '%s': %s (Prio %d) overrides %s (Prio %d)."):format(
							node_type,
							domain_name,
							domain_priority,
							existing_handler_info.domain_name,
							existing_handler_info.domain_priority
						)
					)
					handlerRegistry[node_type] =
						{ func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
				elseif
					domain_priority == existing_handler_info.domain_priority
					and existing_handler_info.domain_name ~= domain_name
				then
					logger.warn(
						"Tungsten Backend Warning",
						("Wolfram Backend: Handler for node type '%s': CONFLICT - %s and %s have same priority (%d). '%s' takes precedence (due to processing order). Consider adjusting priorities."):format(
							node_type,
							domain_name,
							existing_handler_info.domain_name,
							domain_priority,
							domain_name
						)
					)
					handlerRegistry[node_type] =
						{ func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
				elseif domain_priority < existing_handler_info.domain_priority then
					logger.debug(
						"Tungsten Backend",
						("Wolfram Backend: Handler for node type '%s' from %s (Prio %d) NOT overriding existing from %s (Prio %d)."):format(
							node_type,
							domain_name,
							domain_priority,
							existing_handler_info.domain_name,
							existing_handler_info.domain_priority
						)
					)
				end
			else
				handlerRegistry[node_type] =
					{ func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
			end
		end
	else
		local error_msg = ok and ("module '%s' loaded but it did not return a .handlers table."):format(handler_module_path)
			or ("Failed to load module '%s': %s"):format(handler_module_path, tostring(domain_module))
		logger.warn(
			"Tungsten Backend Warning",
			("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. %s"):format(domain_name, error_msg)
		)
	end
end

local function init_handlers(domains, registry)
	if handlers_initialized then
		return
	end

	registry = registry or require("tungsten.core.registry")

	logger.debug("Tungsten Backend", "Wolfram Backend: Lazily initializing handlers...")

	local target_domains_for_handlers = domains
		or (type(config.domains) == "table" and #config.domains > 0) and config.domains
		or { "arithmetic" }

	logger.info(
		"Tungsten Backend",
		"Wolfram Backend: Loading Wolfram handlers for domains: " .. table.concat(target_domains_for_handlers, ", ")
	)

	registry.reset_handlers()

	for _, domain_name in ipairs(target_domains_for_handlers) do
		_process_domain_handlers(domain_name, registry)
	end

	if next(handlerRegistry) == nil then
		logger.error(
			"Tungsten Backend Error",
			"Wolfram Backend: No Wolfram handlers were loaded. AST to string conversion will likely fail or produce incorrect results."
		)
	end

	renderableHandlers = {}
	for node_type, handler_info in pairs(handlerRegistry) do
		renderableHandlers[node_type] = handler_info.func
	end

	registry.register_handlers(renderableHandlers)

	handlers_initialized = true

	logger.debug("Tungsten Backend", "Wolfram Backend: Handlers initialized successfully.")
end

function M.ast_to_wolfram(ast)
	if not handlers_initialized then
		init_handlers(nil, nil)
	end

	if not ast then
		return "Error: AST is nil"
	end
	local registry = require("tungsten.core.registry")
	local handlers = registry.get_handlers()
	if next(renderableHandlers) == nil then
		return "Error: No Wolfram handlers loaded for AST conversion."
	end

	local rendered_result = render.render(ast, handlers)

	if type(rendered_result) == "table" and rendered_result.error then
		local error_message = rendered_result.message
		if rendered_result.node_type then
			error_message = error_message .. " (Node type: " .. rendered_result.node_type .. ")"
		end
		return "Error: AST rendering failed: " .. error_message
	end

	return rendered_result
end

-- Alias for generic backend interface TODO: Refactor to use same name
function M.ast_to_code(ast)
	return M.ast_to_wolfram(ast)
end

function M.evaluate_async(ast, opts, callback)
	assert(type(callback) == "function", "evaluate_async expects callback")

	opts = opts or {}
	local numeric = opts.numeric
	local cache_key = opts.cache_key

	local ok, code = pcall(M.ast_to_wolfram, ast)
	if not ok or not code then
		callback(nil, "Error converting AST to Wolfram code: " .. tostring(code))
		return
	end

	if opts.code then
		code = opts.code
	end

	if config.numeric_mode or numeric then
		code = "N[" .. code .. "]"
	end

	code = "ToString[TeXForm[" .. code .. '], CharacterEncoding -> "UTF8"]'

	async.run_job({ config.wolfram_path, "-code", code }, {
		cache_key = cache_key,
		on_exit = function(exit_code, stdout, stderr)
			if exit_code == 0 then
				if stderr ~= "" then
					logger.debug("Tungsten Debug", "Tungsten Debug (stderr): " .. stderr)
				end
				callback(stdout, nil)
			else
				local err_msg
				if exit_code == -1 or exit_code == 127 then
					err_msg = "WolframScript not found. Check wolfram_path."
				else
					err_msg = ("WolframScript exited with code %d"):format(exit_code)
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

function M.load_handlers(domains, registry_obj)
	logger.info("Tungsten Backend", "Wolfram Backend: Resetting and loading handlers...")
	handlerRegistry = {}
	renderableHandlers = {}
	handlers_initialized = false
	init_handlers(domains, registry_obj)
end

function M.reload_handlers()
	M.load_handlers(nil, nil)
end

manager.register("Wolfram", M)

return M

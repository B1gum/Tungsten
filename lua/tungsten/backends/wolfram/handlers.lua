-- lua/tungsten/backends/wolfram/handlers.lua
-- Manages registration and initialization of Wolfram domain handlers.

local logger = require("tungsten.util.logger")

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

function M.init_handlers(domains, registry)
	if handlers_initialized then
		return
	end

	registry = registry or require("tungsten.core.registry")
	local config = require("tungsten.config")

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
		logger.warn(
			"Tungsten Backend Error",
			"Wolfram Backend: No Wolfram handlers were loaded. AST to string conversion will likely fail or produce incorrect results."
		)
		return
	end

	renderableHandlers = {}
	for node_type, handler_info in pairs(handlerRegistry) do
		renderableHandlers[node_type] = handler_info.func
	end

	registry.register_handlers(renderableHandlers)

	handlers_initialized = true

	logger.debug("Tungsten Backend", "Wolfram Backend: Handlers initialized successfully.")
end

function M.ensure_handlers(domains, registry)
	if not handlers_initialized then
		M.init_handlers(domains, registry)
	end
	return renderableHandlers
end

function M.load_handlers(domains, registry_obj)
	logger.info("Tungsten Backend", "Wolfram Backend: Resetting and loading handlers...")
	handlerRegistry = {}
	renderableHandlers = {}
	handlers_initialized = false
	M.init_handlers(domains, registry_obj)
end

function M.reload_handlers()
	M.load_handlers(nil, nil)
end

return M

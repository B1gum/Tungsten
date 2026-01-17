-- lua/tungsten/backends/python/handlers.lua
-- Manages registration and initialization of Python domain handlers.

local logger = require("tungsten.util.logger")

local M = {}

local handlerRegistry = {}
local renderableHandlers = {}
local handlers_initialized = false
local domain_aliases = { plotting = "plotting_handlers" }

local function should_register_handler(node_type, new_domain, new_prio, registry)
	local existing_handler_info = registry[node_type]

	if not existing_handler_info then
		return "new"
	end

	if new_prio > existing_handler_info.domain_priority then
		return "override"
	end

	if new_prio == existing_handler_info.domain_priority and existing_handler_info.domain_name ~= new_domain then
		return "conflict"
	end

	return "skip"
end

local function _process_domain_handlers(domain_name, registry)
	local module_name = domain_aliases[domain_name] or domain_name
	local handler_module_path = "tungsten.backends.python.domains." .. module_name
	local ok, domain_module = pcall(require, handler_module_path)

	if ok and domain_module and domain_module.handlers then
		local domain_priority = registry.get_domain_priority(domain_name)
		logger.debug(
			"Tungsten Backend",
			("Python Backend: Successfully loaded handlers module from %s for domain %s (Priority: %d)"):format(
				handler_module_path,
				domain_name,
				domain_priority
			)
		)

		for node_type, handler_func in pairs(domain_module.handlers) do
			local status = should_register_handler(node_type, domain_name, domain_priority, handlerRegistry)
			local existing_handler_info = handlerRegistry[node_type]

			if status == "override" then
				logger.debug(
					"Tungsten Backend",
					("Python Backend: Handler for node type '%s': %s (Prio %d) overrides %s (Prio %d)."):format(
						node_type,
						domain_name,
						domain_priority,
						existing_handler_info.domain_name,
						existing_handler_info.domain_priority
					)
				)
				handlerRegistry[node_type] =
					{ func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
			elseif status == "conflict" then
				logger.warn(
					"Tungsten Backend Warning",
					("Python Backend: Handler for node type '%s': CONFLICT - %s and %s have same priority (%d). '%s' takes precedence (due to processing order). Consider adjusting priorities."):format(
						node_type,
						domain_name,
						existing_handler_info.domain_name,
						domain_priority,
						domain_name
					)
				)
				handlerRegistry[node_type] =
					{ func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
			elseif status == "skip" and existing_handler_info and domain_priority < existing_handler_info.domain_priority then
				logger.debug(
					"Tungsten Backend",
					("Python Backend: Handler for node type '%s' from %s (Prio %d) NOT overriding existing from %s (Prio %d)."):format(
						node_type,
						domain_name,
						domain_priority,
						existing_handler_info.domain_name,
						existing_handler_info.domain_priority
					)
				)
			elseif status == "new" then
				handlerRegistry[node_type] =
					{ func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
			end
		end
	else
		local error_msg = ok and ("module '%s' loaded but it did not return a .handlers table."):format(handler_module_path)
			or ("Failed to load module '%s': %s"):format(handler_module_path, tostring(domain_module))
		logger.warn(
			"Tungsten Backend Warning",
			("Python Backend: Could not load Python handlers for domain '%s'. %s"):format(domain_name, error_msg)
		)
	end
end

function M.init_handlers(domains, registry)
	if handlers_initialized then
		return
	end

	registry = registry or require("tungsten.core.registry")
	local config = require("tungsten.config")

	logger.debug("Tungsten Backend", "Python Backend: Lazily initializing handlers...")

	local target_domains_for_handlers = domains
		or (type(config.domains) == "table" and #config.domains > 0) and config.domains
		or { "arithmetic" }

	logger.info(
		"Tungsten Backend",
		"Python Backend: Loading Python handlers for domains: " .. table.concat(target_domains_for_handlers, ", ")
	)

	registry.reset_handlers()

	for _, domain_name in ipairs(target_domains_for_handlers) do
		_process_domain_handlers(domain_name, registry)
	end

	if next(handlerRegistry) == nil then
		logger.error(
			"Tungsten Backend Error",
			"Python Backend: No Python handlers were loaded. AST to string conversion will likely fail or produce incorrect results."
		)
	end

	renderableHandlers = {}
	for node_type, handler_info in pairs(handlerRegistry) do
		renderableHandlers[node_type] = handler_info.func
	end

	registry.register_handlers(renderableHandlers)

	handlers_initialized = true

	logger.debug("Tungsten Backend", "Python Backend: Handlers initialized successfully.")
end

function M.ensure_handlers(domains, registry)
	if not handlers_initialized then
		M.init_handlers(domains, registry)
	end
	return renderableHandlers
end

function M.load_handlers(domains, registry_obj)
	logger.info("Tungsten Backend", "Python Backend: Resetting and loading handlers...")
	handlerRegistry = {}
	renderableHandlers = {}
	handlers_initialized = false
	M.init_handlers(domains, registry_obj)
end

function M.reload_handlers()
	M.load_handlers(nil, nil)
end

return M

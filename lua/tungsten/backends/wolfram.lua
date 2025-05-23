-- backends/wolfram.lua
-- Handles all interaction with the WolframEngine.
---------------------------------------------------------------------
local render = require "tungsten.core.render"
local config = require "tungsten.config"
local logger = require "tungsten.util.logger"

local M = {}
local handlerRegistry = {}
local renderableHandlers = {}
local handlers_initialized = false

local function _process_domain_handlers(domain_name, registry)
    local handler_module_path = "tungsten.domains." .. domain_name .. ".wolfram_handlers"
    local ok, domain_module = pcall(require, handler_module_path)

    if ok and domain_module and domain_module.handlers then
        local domain_priority = registry.get_domain_priority(domain_name)
        if config.debug then
            logger.notify(("Wolfram Backend: Successfully loaded handlers module from %s for domain %s (Priority: %d)"):format(handler_module_path, domain_name, domain_priority), logger.levels.DEBUG, { title = "Tungsten Debug" })
        end

        for node_type, handler_func in pairs(domain_module.handlers) do
            if handlerRegistry[node_type] then
                local existing_handler_info = handlerRegistry[node_type]
                if domain_priority > existing_handler_info.domain_priority then
                    logger.notify(
                        ("Wolfram Backend: Handler for node type '%s': %s (Prio %d) overrides %s (Prio %d)."):format(
                            node_type, domain_name, domain_priority,
                            existing_handler_info.domain_name, existing_handler_info.domain_priority),
                        logger.levels.DEBUG, { title = "Tungsten Backend" }
                    )
                    handlerRegistry[node_type] = { func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
                elseif domain_priority == existing_handler_info.domain_priority and existing_handler_info.domain_name ~= domain_name then
                    logger.notify(
                        ("Wolfram Backend: Handler for node type '%s': CONFLICT - %s and %s have same priority (%d). '%s' takes precedence (due to processing order). Consider adjusting priorities."):format(
                            node_type, domain_name, existing_handler_info.domain_name, domain_priority, domain_name),
                        logger.levels.WARN, { title = "Tungsten Backend Warning" }
                    )
                    handlerRegistry[node_type] = { func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
                elseif domain_priority < existing_handler_info.domain_priority then
                     logger.notify(
                        ("Wolfram Backend: Handler for node type '%s' from %s (Prio %d) NOT overriding existing from %s (Prio %d)."):format(
                            node_type, domain_name, domain_priority,
                            existing_handler_info.domain_name, existing_handler_info.domain_priority),
                        logger.levels.DEBUG, { title = "Tungsten Backend" }
                    )
                end
            else
                handlerRegistry[node_type] = { func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
            end
        end
    else
        local error_msg = ok and ("module '%s' loaded but it did not return a .handlers table."):format(handler_module_path) or ("Failed to load module '%s': %s"):format(handler_module_path, tostring(domain_module))
        logger.notify(
            ("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. %s"):format(domain_name, error_msg),
            logger.levels.WARN, { title = "Tungsten Backend Warning" }
        )
    end
end

local function initialize_handlers()
    if handlers_initialized then
        return
    end

    local registry = require("tungsten.core.registry")

    if config.debug then
      logger.notify("Wolfram Backend: Lazily initializing handlers...", logger.levels.DEBUG, { title = "Tungsten Backend" })
    end

    local target_domains_for_handlers = (config.domains and #config.domains > 0) and config.domains or { "arithmetic" }

    if config.debug then
        logger.notify("Wolfram Backend: Loading Wolfram handlers for domains: " .. table.concat(target_domains_for_handlers, ", "), logger.levels.INFO, { title = "Tungsten Backend" })
    end

    for _, domain_name in ipairs(target_domains_for_handlers) do
        _process_domain_handlers(domain_name, registry)
    end

    if next(handlerRegistry) == nil then
        logger.notify(
            "Wolfram Backend: No Wolfram handlers were loaded. AST to string conversion will likely fail or produce incorrect results.",
            logger.levels.ERROR, { title = "Tungsten Backend Error" }
        )
    end

    renderableHandlers = {}
    for node_type, handler_info in pairs(handlerRegistry) do
        renderableHandlers[node_type] = handler_info.func
    end

    handlers_initialized = true
    if config.debug then
      logger.notify("Wolfram Backend: Handlers initialized successfully.", logger.levels.DEBUG, { title = "Tungsten Backend" })
    end
end

function M.to_string(ast)
    if not handlers_initialized then
        initialize_handlers()
    end

    if not ast then
        logger.notify("Wolfram Backend: to_string called with a nil AST.", logger.levels.ERROR, { title = "Tungsten Backend Error" })
        return "Error: AST is nil"
    end
    if next(renderableHandlers) == nil then
        logger.notify("Wolfram Backend: No Wolfram handlers available when to_string was called.", logger.levels.ERROR, { title = "Tungsten Backend Error" })
        return "Error: No Wolfram handlers loaded for AST conversion."
    end

    local rendered_result = render.render(ast, renderableHandlers)

    if type(rendered_result) == "table" and rendered_result.error then
        local error_message = rendered_result.message
        if rendered_result.node_type then
             error_message = error_message .. " (Node type: " .. rendered_result.node_type .. ")"
        end
        logger.notify("Wolfram Backend: Error during AST rendering: " .. error_message, logger.levels.ERROR, { title = "Tungsten Backend Error" })
        return "Error: AST rendering failed: " .. error_message
    end

    return rendered_result
end


function M.reset_and_reinit_handlers()
    logger.notify("Wolfram Backend: Resetting and re-initializing handlers...", logger.levels.INFO, { title = "Tungsten Backend" })
    handlerRegistry = {}
    renderableHandlers = {}
    handlers_initialized = false
    initialize_handlers()
end

return M


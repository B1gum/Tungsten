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
    local handler_module_path = "tungsten.backends.wolfram.domains." .. domain_name
    local ok, domain_module = pcall(require, handler_module_path)

    if ok and domain_module and domain_module.handlers then
        local domain_priority = registry.get_domain_priority(domain_name)
          logger.debug("Tungsten Debug", ("Wolfram Backend: Successfully loaded handlers module from %s for domain %s (Priority: %d)"):format(handler_module_path, domain_name, domain_priority))

        for node_type, handler_func in pairs(domain_module.handlers) do
            if handlerRegistry[node_type] then
                local existing_handler_info = handlerRegistry[node_type]
                if domain_priority > existing_handler_info.domain_priority then
                    logger.debug("Tungsten Backend", ("Wolfram Backend: Handler for node type '%s': %s (Prio %d) overrides %s (Prio %d)."):format(
                        node_type, domain_name, domain_priority,
                        existing_handler_info.domain_name, existing_handler_info.domain_priority))
                    handlerRegistry[node_type] = { func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
                elseif domain_priority == existing_handler_info.domain_priority and existing_handler_info.domain_name ~= domain_name then
                    logger.warn("Tungsten Backend Warning", ("Wolfram Backend: Handler for node type '%s': CONFLICT - %s and %s have same priority (%d). '%s' takes precedence (due to processing order). Consider adjusting priorities."):format(
                            node_type, domain_name, existing_handler_info.domain_name, domain_priority, domain_name))
                    handlerRegistry[node_type] = { func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
                elseif domain_priority < existing_handler_info.domain_priority then
                    logger.debug("Tungsten Backend", ("Wolfram Backend: Handler for node type '%s' from %s (Prio %d) NOT overriding existing from %s (Prio %d)."):format(
                        node_type, domain_name, domain_priority,
                        existing_handler_info.domain_name, existing_handler_info.domain_priority))
                end
            else
                handlerRegistry[node_type] = { func = handler_func, domain_name = domain_name, domain_priority = domain_priority }
            end
        end
    else
        local error_msg = ok and ("module '%s' loaded but it did not return a .handlers table."):format(handler_module_path) or ("Failed to load module '%s': %s"):format(handler_module_path, tostring(domain_module))
        logger.warn("Tungsten Backend Warning", ("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. %s"):format(domain_name, error_msg))
    end
end

local function init_handlers()
    if handlers_initialized then
        return
    end

    local registry = require("tungsten.core.registry")

    logger.debug("Tungsten Backend", "Wolfram Backend: Lazily initializing handlers...")

    local target_domains_for_handlers
    if type(config.domains) == 'table' and not vim.tbl_islist(config.domains) then
        target_domains_for_handlers = {}
        for name, prio in pairs(config.domains) do
            table.insert(target_domains_for_handlers, name)
            registry.set_domain_priority(name, prio)
        end
        if #target_domains_for_handlers == 0 then
            target_domains_for_handlers = { "arithmetic" }
        end
    else
        target_domains_for_handlers = (config.domains and #config.domains > 0) and config.domains or { "arithmetic" }
    end

    logger.info("Tungsten Backend", "Wolfram Backend: Loading Wolfram handlers for domains: " .. table.concat(target_domains_for_handlers, ", "))

    for _, domain_name in ipairs(target_domains_for_handlers) do
        _process_domain_handlers(domain_name, registry)
    end

    if next(handlerRegistry) == nil then
      logger.error("Tungsten Backend Error", "Wolfram Backend: No Wolfram handlers were loaded. AST to string conversion will likely fail or produce incorrect results.")
    end

    renderableHandlers = {}
    for node_type, handler_info in pairs(handlerRegistry) do
        renderableHandlers[node_type] = handler_info.func
    end

    handlers_initialized = true

    logger.debug("Tungsten Backend", "Wolfram Backend: Handlers initialized successfully.")
end

function M.ast_to_wolfram(ast)
    if not handlers_initialized then
        init_handlers()
    end

    if not ast then
        return "Error: AST is nil"
    end
    if next(renderableHandlers) == nil then
        return "Error: No Wolfram handlers loaded for AST conversion."
    end

    local rendered_result = render.render(ast, renderableHandlers)

    if type(rendered_result) == "table" and rendered_result.error then
        local error_message = rendered_result.message
        if rendered_result.node_type then
             error_message = error_message .. " (Node type: " .. rendered_result.node_type .. ")"
        end
        return "Error: AST rendering failed: " .. error_message
    end

    return rendered_result
end


function M.reload_handlers()
    logger.info("Tungsten Backend", "Wolfram Backend: Resetting and re-initializing handlers...")
    handlerRegistry = {}
    renderableHandlers = {}
    handlers_initialized = false
    init_handlers()
end

return M


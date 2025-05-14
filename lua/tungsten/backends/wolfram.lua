-- backends/wolfram.lua
-- Handles all interaction with the WolframEngine.
---------------------------------------------------------------------

local render = require("tungsten.core.render")
local config = require("tungsten.config")
local logger = require("tungsten.util.logger") -- Ensure logger is available and used

----------------------------------------------------------------
-- Aggregated handlers table
local H = {}

-- Retrieve the list of domains to load
-- Defaults to {"arithmetic"} if not specified in config.lua
local domains_to_load = (config.domains and #config.domains > 0) and config.domains or { "arithmetic" }

if config.debug then
  logger.notify("Wolfram Backend: Loading Wolfram handlers for domains: " .. table.concat(domains_to_load, ", "), logger.levels.INFO, { title = "Tungsten Backend" })
end

for _, domain_name in ipairs(domains_to_load) do
  local handler_module_path = "tungsten.domains." .. domain_name .. ".wolfram_handlers"
  -- Use pcall to safely attempt to require the module
  local ok, domain_module = pcall(require, handler_module_path)

  if ok and domain_module and domain_module.handlers then
    if config.debug then
      logger.notify("Wolfram Backend: Successfully loaded handlers from " .. handler_module_path, logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
    for node_type, handler_func in pairs(domain_module.handlers) do
      if H[node_type] then
        -- Log a warning if a handler is being overridden
        logger.notify(
          ("Wolfram Backend: Handler for node type '%s' from domain '%s' is overriding an existing handler."):format(node_type, domain_name),
          logger.levels.WARN,
          { title = "Tungsten Backend Warning" }
        )
      end
      H[node_type] = handler_func
    end
  else
    -- Log a warning if handlers for a domain could not be loaded
    local error_msg = ok and "but it did not return a .handlers table." or (tostring(domain_module)) -- domain_module contains error if not ok
    logger.notify(
      ("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. Module '%s' load failed %s"):format(domain_name, handler_module_path, error_msg),
      logger.levels.WARN,
      { title = "Tungsten Backend Warning" }
    )
  end
end

if next(H) == nil then -- Check if the H table is empty after attempting to load all domain handlers
  logger.notify(
    "Wolfram Backend: No Wolfram handlers were loaded. AST to string conversion will likely fail or produce incorrect results.",
    logger.levels.ERROR,
    { title = "Tungsten Backend Error" }
  )
end

----------------------------------------------------------------
-- Public API
local M = {}

--- Converts an Abstract Syntax Tree (AST) to a Wolfram Language string.
---@param ast table The AST to convert.
---@return string The Wolfram Language string representation of the AST.
function M.to_string(ast)
  if not ast then
    logger.notify("Wolfram Backend: to_string called with a nil AST.", logger.levels.ERROR, { title = "Tungsten Backend Error" })
    return "Error: AST is nil"
  end
  if next(H) == nil then
     logger.notify("Wolfram Backend: No Wolfram handlers loaded when to_string was called.", logger.levels.ERROR, { title = "Tungsten Backend Error" })
    return "Error: No Wolfram handlers loaded for AST conversion."
  end
  -- Use the core rendering function with the aggregated handlers
  local ok, result_string = pcall(render.render, ast, H)
  if not ok then
    logger.notify("Wolfram Backend: Error during AST rendering: " .. tostring(result_string), logger.levels.ERROR, { title = "Tungsten Backend Error" })
    return "Error: AST rendering failed" -- Or handle error more gracefully
  end
  return result_string
end

return M

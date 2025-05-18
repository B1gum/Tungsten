local M = {}
local config = require("tungsten.config")
local logger = require "tungsten.util.logger"

M.metadata = {
  name = "calculus",
  priority = 150,
  dependencies = {},
  provides = {}
}

function M.get_metadata()
  return M.metadata
end

function M.init_grammar()
  -- Lazily require dependencies for this function if not already loaded
  if not config then config = require("tungsten.config") end
  if not logger then logger = require("tungsten.util.logger") end
  -- if not registry then registry = require("tungsten.core.registry") end -- For later

  if config.debug then
    logger.notify("Calculus Domain: Initializing grammar contributions...", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  -- Actual grammar registration will go here later.

  if config.debug then
    logger.notify("Calculus Domain: Grammar contributions registered (none yet).", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end
end

return M


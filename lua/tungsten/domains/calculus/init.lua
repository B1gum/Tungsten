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
  if not config then config = require("tungsten.config") end
  if not logger then logger = require("tungsten.util.logger") end

  if config.debug then
    logger.notify("Calculus Domain: Initializing grammar contributions...", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end


  if config.debug then
    logger.notify("Calculus Domain: Grammar contributions registered (none yet).", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end
end

return M


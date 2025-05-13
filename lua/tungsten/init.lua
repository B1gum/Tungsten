-- init.lua
-- Main initiation module for the plugin
--------------------------------------------

local M = {}

function M.setup()
  require("tungsten.core.commands")
  require("tungsten.ui.which_key")
  require("tungsten.ui")
  require("tungsten.core")
end

return M

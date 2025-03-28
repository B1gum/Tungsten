-- init.lua
-- Main initiation module for the plugin
--------------------------------------------

local M = {}

function M.setup()
  require("tungsten.commands")
  require("tungsten.which_key")
  require("tungsten.telescope")
end

return M

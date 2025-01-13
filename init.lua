---------------------------------------------------------------------------------
-- init.lua
-- The main entry point that initializes the plugin and sets up commands
--------------------------------------------------------------------------------- 

local evaluate = require("tungsten.evaluate")
local simplify = require("tungsten.simplify")
local plot     = require("tungsten.plot")
local solve    = require("tungsten.solve")
local telescope = require("tungsten.telescope")
local which_key = require("tungsten.which_key")
local tests    = require("tungsten.tests")

local M = {}

function M.setup()
  -- Setup commands
  evaluate.setup_commands()
  simplify.setup_commands()
  plot.setup_commands()
  solve.setup_commands()
  tests.setup_commands()
end

return M

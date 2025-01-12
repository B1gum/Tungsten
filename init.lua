-- The main entry point that initializes the plugin and sets up commands.

local evaluate = require("wolfram.evaluate")
local simplify = require("wolfram.simplify")
local plot     = require("wolfram.plot")
local solve    = require("wolfram.solve")
local telescope = require("wolfram.telescope")
local which_key = require("wolfram.which_key")
local tests    = require("wolfram.tests")

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

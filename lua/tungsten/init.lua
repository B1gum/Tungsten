-- init.lua
-- Main initiation module for the plugin
--------------------------------------------

local defaults = require('tungsten.config')
local M = { config = vim.deepcopy(defaults) }


function M.setup(user_opts)
  if user_opts ~= nil and type(user_opts) ~= 'table' then
    error('tungsten.setup: options table expected', 2)
  end

  if user_opts and next(user_opts) then
    M.config = vim.tbl_deep_extend('force', vim.deepcopy(M.config), user_opts)
  end

  package.loaded['tungsten.config'] = M.config

  require('tungsten.core.commands')
  require('tungsten.ui.which_key')
  require('tungsten.ui.commands')
  require('tungsten.ui')
  require('tungsten.core')
end

return M


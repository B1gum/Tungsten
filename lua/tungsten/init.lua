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

  require('tungsten.util.logger').set_level(M.config.log_level or 'INFO')

  package.loaded['tungsten.config'] = M.config

  require('tungsten.core.commands')
  require('tungsten.ui.which_key')
  require('tungsten.ui.commands')
  require('tungsten.ui')
  require('tungsten.core')

  local registry = require('tungsten.core.registry')
  for _, cmd in ipairs(registry.commands) do
    vim.api.nvim_create_user_command(cmd.name, cmd.func, cmd.opts or { desc = cmd.desc })
  end
end

return M


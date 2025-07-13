local M = {}

local logger = require('tungsten.util.logger')

vim.api.nvim_create_user_command('TungstenPalette', function()
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    vim.schedule(function()
      logger.warn('Telescope not found. Install telescope.nvim for enhanced UI.')
    end)
    return
  end

  if not telescope.extensions.tungsten.open() then
    pcall(telescope.load_extension, 'tungsten')
  end
  local ext = telescope.extensions.tungsten
  if ext and ext.open then
    ext.open()
  else
    vim.schedule(function()
      logger.warn('Failed to load Tungsten telescope extension.')
    end)
  end
end, { desc = 'Open Tungsten command palette' })

return M


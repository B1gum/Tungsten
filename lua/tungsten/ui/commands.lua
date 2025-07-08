local M = {}

vim.api.nvim_create_user_command('TungstenPalette', function()
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    vim.schedule(function()
      vim.notify('Telescope not found. Install telescope.nvim for enhanced UI.', vim.log.levels.WARN)
    end)
    return
  end
  telescope.extensions.tungsten.open()
end, { desc = 'Open Tungsten command palette' })

return M

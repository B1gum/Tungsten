local actions      = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local logger       = require 'tungsten.util.logger'

local M = {}

function M.attach(prompt_bufnr, _)
  actions.select_default:replace(function()
    actions.close(prompt_bufnr)
    local entry = action_state.get_selected_entry()

    if entry and entry.value then
      vim.cmd(entry.value)
    else
      logger.warn("Tungsten", "No command selected")
    end
  end)
  return true
end

return M


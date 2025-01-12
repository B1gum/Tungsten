-- Configures Telescope integrations for the plugin.

local actions = require('telescope.actions')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')

local M = {}

-- Function to dynamically retrieve Wolfram commands
local function get_wolfram_commands()
  local commands = vim.api.nvim_get_commands({})
  local wolfram_commands = {}

  for cmd_name, cmd in pairs(commands) do
    if cmd_name:match("^Wolfram") then
      table.insert(wolfram_commands, { name = cmd.description or cmd_name, cmd = cmd_name })
    end
  end

  return wolfram_commands
end

-- Custom Telescope picker for Wolfram commands
function M.open_wolfram_picker()
  local wolfram_commands = get_wolfram_commands()

  if #wolfram_commands == 0 then
    vim.notify("No Wolfram commands found.", vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = "Wolfram Commands",
    finder = finders.new_table {
      results = wolfram_commands,
      entry_maker = function(entry)
        return {
          value = entry.cmd,
          display = entry.name,
          ordinal = entry.name,
        }
      end,
    },
    sorter = sorters.get_fuzzy_file(),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = require('telescope.actions.state').get_selected_entry()
        if selection and selection.value then
          vim.cmd(':' .. selection.value)
        else
          vim.notify("No command selected", vim.log.levels.WARN)
        end
      end)
      return true
    end,
  }):find()
end

return M


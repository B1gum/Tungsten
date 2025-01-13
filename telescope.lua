--------------------------------------------------------------------------------
-- telescope.lua
-- Configures Telescope integrations for the plugin.
--------------------------------------------------------------------------------

-- 1) setup
--------------------------------------------------------------------------------
local actions = require('telescope.actions')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')

local M = {}




-- 2) Dynamically retrieve Tungsten commands
--------------------------------------------------------------------------------
local function get_tungsten_commands()
  local commands = vim.api.nvim_get_commands({})  -- Fetches all user-defined commands
  local tungsten_commands = {}

  for cmd_name, cmd in pairs(commands) do   -- Iterates over all user-defined commands, with cmd_name = name of command and cmd = command details
    if cmd_name:match("^Tungsten") then     -- Checks if command name starts with Tungsten
      table.insert(tungsten_commands, { name = cmd.description or cmd_name, cmd = cmd_name })   -- Adds a new table to tungsten_commands for each matching command 
    end
  end

  return tungsten_commands  -- Returns a list of all "Tungsten" commands
end




-- 3) Custom Telescope picker for Tungsten commands
--------------------------------------------------------------------------------
function M.open_tungsten_picker()   -- Function that opens the custem telescope command-picker listing all "Tungsten" commands
  local tungsten_commands = get_tungsten_commands()   -- Calls previously defined function to get the list of all "Tungsten" commands

  if #tungsten_commands == 0 then   -- If no "Tungsten" commands are found, then
    vim.notify("No Tungsten commands found.", vim.log.levels.WARN)  -- Print a warning saying that no commands were found
    return
  end

  pickers.new({}, {
    prompt_title = "Tungsten Commands",   -- Sets picker-title
    finder = finders.new_table {          -- Specifies the data-source for the picker
      results = tungsten_commands,        -- Supplies the list of "Tungsten" commands as the list of results to display
      entry_maker = function(entry)       -- Defines how each entry should be formatted
        return {
          value = entry.cmd,              -- Actual command-name, e.g. TungstenSimplify
          display = entry.name,           -- Sets the display name
          ordinal = entry.name,           -- Sorting and filtering based on display name
        }
      end,
    },
    sorter = sorters.get_fuzzy_file(),    -- Sort with a general-purpose fuzzy-sorter
    attach_mappings = function(prompt_bufnr, map)   -- Customizes keymappings and actions within the picker
      actions.select_default:replace(function()     -- Overrides default action for selection of an entry
        actions.close(prompt_bufnr)                 -- Closes the picker
        local selection = require('telescope.actions.state').get_selected_entry()   -- Retrieves the currently selected entry
        if selection and selection.value then
          vim.cmd(':' .. selection.value)           -- Executes the command
        else
          vim.notify("No command selected", vim.log.levels.WARN)  -- If an "invalid" command is selected then notify the user
        end
      end)
      return true
    end,
  }):find()
end

return M


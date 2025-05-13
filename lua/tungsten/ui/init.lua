local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')

local picker   = require('tungsten.ui.picker')
local mappings = require('tungsten.ui.mappings')

local M = {}

---Opens a Telescope list of all :Tungsten* commands.
---@param opts table|nil  -- forwarded to `pickers.new`
function M.open(opts)
  opts = opts or {}

  local commands = picker.list()
  if vim.tbl_isempty(commands) then
    vim.notify("No Tungsten commands found.", vim.log.levels.WARN)
    return
  end

  pickers.new(opts, {
    prompt_title    = "Tungsten Commands",
    finder          = finders.new_table {
      results = commands,
      entry_maker = function(e)
        return {
          value   = e.value,    -- executed by mappings.attach
          display = e.display,  -- what the user sees
          ordinal = e.ordinal,  -- used for fuzzy filtering
        }
      end,
    },
    sorter          = sorters.get_fuzzy_file(),
    attach_mappings = mappings.attach,
  }):find()
end

return M


local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local sorters = require 'telescope.sorters'

local picker   = require 'tungsten.ui.picker'
local mappings = require 'tungsten.ui.mappings'
local logger   = require 'tungsten.util.logger'

local M = {}

function M.open(opts)
  opts = opts or {}

  local commands = picker.list()
  if vim.tbl_isempty(commands) then
    logger.notify("No Tungsten commands found.", logger.log.levels.WARN)
    return
  end

  pickers.new(opts, {
    prompt_title    = "Tungsten Commands",
    finder          = finders.new_table {
      results = commands,
      entry_maker = function(e)
        return {
          value   = e.value,
          display = e.display,
          ordinal = e.ordinal,
        }
      end,
    },
    sorter          = sorters.get_fuzzy_file(),
    attach_mappings = mappings.attach,
  }):find()
end

return M


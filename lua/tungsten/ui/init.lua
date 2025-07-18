local picker = require("tungsten.ui.picker")
local mappings = require("tungsten.ui.mappings")
local logger = require("tungsten.util.logger")

local M = {}

local function open_picker(opts)
	local ok, pickers = pcall(require, "telescope.pickers")
	if not ok then
		vim.schedule(function()
			logger.warn("Telescope not found. Install telescope.nvim for enhanced UI.")
		end)
		return
	end
	local finders = require("telescope.finders")
	local sorters = require("telescope.sorters")

	opts = opts or {}

	local commands = picker.list()
	if vim.tbl_isempty(commands) then
		logger.warn("Tungsten", "No Tungsten commands found.")
		return
	end

	pickers
		.new(opts, {
			prompt_title = "Tungsten Commands",
			finder = finders.new_table({
				results = commands,
				entry_maker = function(e)
					return {
						value = e.value,
						display = e.display,
						ordinal = e.ordinal,
					}
				end,
			}),
			sorter = sorters.get_fuzzy_file(),
			attach_mappings = mappings.attach,
		})
		:find()
end

M.open = open_picker

local ok, telescope = pcall(require, "telescope")
if ok then
	telescope.register_extension({ exports = { open = open_picker } })
end

return M

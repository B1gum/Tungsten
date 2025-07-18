local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
	error("telescope.nvim is required for tungsten extension")
end

local tungsten_ui = require("tungsten.ui")
return telescope.register_extension({
	exports = {
		open = tungsten_ui.open,
	},
})

-- test_init.lua

-- 1. Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- 2. Configure Tungsten with the build hook
require("lazy").setup({
	{
		"B1gum/Tungsten",
		dir = "/work/tungsten", -- Load from the mounted Docker volume
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			"folke/which-key.nvim",
		},
		-- This is the line that triggers the automatic install
		build = "./scripts/install_python_deps.sh",
		opts = {},
	},
})

-- 3. Verification UI: Open the Lazy log automatically to see the build progress
vim.api.nvim_create_autocmd("User", {
	pattern = "LazyDone",
	callback = function()
		vim.cmd("Lazy log")
	end,
})

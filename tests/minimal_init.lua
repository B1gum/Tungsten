-- tests/minimal_init.lua
-- Minimal init.lua for running tests.

local project_root = vim.fn.getcwd()
if not project_root or project_root == "" then
	return
end

local major_version, minor_version = _VERSION:match("Lua (%d)%.(%d)")
local lua_version_short = major_version .. "." .. minor_version

local rocktree = os.getenv("TUNGSTEN_TEST_ROCKTREE")
if not rocktree or rocktree == "" then
	rocktree = project_root .. "/.test_deps/rocks"
end

local rocktree_share = rocktree .. "/share/lua/" .. lua_version_short
local rocktree_lib = rocktree .. "/lib/lua/" .. lua_version_short

package.path = rocktree_share .. "/?.lua;" .. rocktree_share .. "/?/init.lua;" .. package.path
package.cpath = rocktree_lib .. "/?.so;" .. package.cpath

package.path = package.path .. ";" .. project_root .. "/lua/?.lua"
package.path = package.path .. ";" .. project_root .. "/lua/?/init.lua"

local plenary_path = os.getenv("TUNGSTEN_TEST_PLENARY")
if not plenary_path or plenary_path == "" then
	plenary_path = project_root .. "/.test_deps/plenary.nvim"
end

if vim.fn.isdirectory(plenary_path) == 0 then
	error("Tungsten test dependency plenary.nvim is missing at " .. plenary_path .. ". Run `make test_deps` first.")
end

vim.opt.rtp:prepend(plenary_path)
vim.opt.rtp:prepend(project_root)

vim.treesitter = vim.treesitter or {}
vim.treesitter.get_parser = vim.treesitter.get_parser or function()
	return {
		parse = function() end,
	}
end
vim.treesitter.start = vim.treesitter.start or function() end
vim.treesitter.query = vim.treesitter.query or {}
vim.treesitter.query.get = vim.treesitter.query.get or function()
	return nil
end
vim.treesitter.query.parse = vim.treesitter.query.parse or function()
	return nil
end

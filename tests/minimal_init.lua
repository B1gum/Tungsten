-- tests/minimal_init.lua
-- Minimal init.lua for running tests.

local luarocks_path = os.getenv("LUAROCKS_PATH") or os.getenv("LUA_PATH")
if luarocks_path then
	package.path = luarocks_path .. ";" .. package.path
end

local luarocks_cpath = os.getenv("LUAROCKS_CPATH") or os.getenv("LUA_CPATH")
if luarocks_cpath then
	package.cpath = luarocks_cpath .. ";" .. package.cpath
end

local home = os.getenv("HOME")
if not home then
	return
end

local major_version, minor_version = _VERSION:match("Lua (%d)%.(%d)")
local lua_version_short = major_version .. "." .. minor_version

local rocktree_share = home .. "/.luarocks/share/lua/" .. lua_version_short
local rocktree_lib = home .. "/.luarocks/lib/lua/" .. lua_version_short

package.path = rocktree_share .. "/?.lua;" .. rocktree_share .. "/?/init.lua;" .. package.path
package.cpath = rocktree_lib .. "/?.so;" .. package.cpath

local project_root = vim.fn.getcwd()
if project_root and project_root ~= "" then
	package.path = package.path .. ";" .. project_root .. "/lua/?.lua"
	package.path = package.path .. ";" .. project_root .. "/lua/?/init.lua"
end

local plenary_path = home .. "/.local/share/nvim/lazy/plenary.nvim"

if vim.fn.empty(vim.fn.glob(plenary_path)) > 0 then
	os.execute(string.format("git clone --depth 1 https://github.com/nvim-lua/plenary.nvim %s", plenary_path))
end
vim.opt.rtp:prepend(plenary_path)

if project_root and project_root ~= "" then
	vim.opt.rtp:prepend(project_root)
end

vim.treesitter = vim.treesitter or {}
vim.treesitter.get_parser = vim.treesitter.get_parser or function()
	return { parse = function() end }
end
vim.treesitter.start = vim.treesitter.start or function() end
vim.treesitter.query = vim.treesitter.query or {}
vim.treesitter.query.get = vim.treesitter.query.get or function()
	return nil
end
vim.treesitter.query.parse = vim.treesitter.query.parse or function()
	return nil
end

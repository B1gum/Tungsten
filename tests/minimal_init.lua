-- tests/minimal_init.lua
-- Minimal init.lua for running tests.

local luarocks_path = os.getenv("LUAROCKS_PATH")
if luarocks_path then
  package.path = luarocks_path .. ';' .. package.path
end

local luarocks_cpath = os.getenv("LUAROCKS_CPATH")
if luarocks_cpath then
  package.cpath = luarocks_cpath .. ';' .. package.cpath
end

local home = os.getenv("HOME")
if not home then
  print("Error: HOME environment variable not set.")
  return
end

local major_version, minor_version = _VERSION:match("Lua (%d)%.(%d)")
local lua_version_short = major_version .. "." .. minor_version

local rocktree_share = home .. "/.local/share/lua/" .. lua_version_short
local rocktree_lib = home .. "/.local/lib/lua/" .. lua_version_short

package.path = rocktree_share .. "/?.lua;" .. rocktree_share .. "/?/init.lua;" .. package.path
package.cpath = rocktree_lib .. "/?.so;" .. package.cpath

local project_root = vim.fn.getcwd()
if project_root and project_root ~= "" then
  package.path = package.path .. ";" .. project_root .. "/lua/?.lua"
  package.path = package.path .. ";" .. project_root .. "/lua/?/init.lua"
else
  print("Error: Could not determine project root.")
end

local plenary_path = home .. "/.local/share/nvim/lazy/plenary.nvim"
vim.opt.rtp:prepend(plenary_path)


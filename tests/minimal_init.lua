-- tests/minimal_init.lua
-- Minimal init.lua for running tests.

local rocktree = os.getenv("HOME") .. "/.local"

local function get_luarocks_path(path_type)
  local cmd = string.format("luarocks --tree=%s path --lua-version=5.1 %s", rocktree, path_type)
  local handle = io.popen(cmd)
  if not handle then return "" end
  local output = handle:read("*a")
  handle:close()
  return output:gsub("[\r\n]", "")
end

local lua_path = get_luarocks_path("--lr-path")
local cpath = get_luarocks_path("--lr-cpath")

package.path = lua_path .. ";" .. package.path
package.cpath = cpath .. ";" .. package.cpath

local tungsten_root = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.stdpath("config") .. "/lua/tungsten"), ":h:h")
package.path = package.path .. ";" .. tungsten_root .. "/lua/?.lua"
package.path = package.path .. ";" .. tungsten_root .. "/lua/?/init.lua"

vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/plenary.nvim")

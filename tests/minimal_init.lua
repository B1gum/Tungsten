-- tests/minimal_init.lua
-- Minimal init.lua for running tests.
local home = os.getenv("HOME")
if not home then
  print("Error: HOME environment variable not set.")
  return
end

local rocktree_share = home .. "/.local/share/lua/5.1"
local rocktree_lib = home .. "/.local/lib/lua/5.1"

package.path = rocktree_share .. "/?.lua;" .. rocktree_share .. "/?/init.lua;" .. package.path
package.cpath = rocktree_lib .. "/?.so;" .. package.cpath

local project_root = vim.fn.getcwd()
if project_root and project_root ~= "" then
  package.path = package.path .. ";" .. project_root .. "/lua/?.lua"
  package.path = package.path .. ";" .. project_root .. "/lua/?/init.lua"
else
  print("Error: Could not determine project root.")
end

vim.opt.rtp:prepend(home .. "/.local/share/nvim/site/pack/plugins/start/plenary.nvim")


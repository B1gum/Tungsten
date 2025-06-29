-- tests/minimal_init.lua

local project_root = os.getenv("TUNGSTEN_PROJECT_ROOT") or vim.loop.cwd()
vim.opt.runtimepath:prepend(project_root)

local function add_neovim_plugin(path)
  local p = vim.fn.expand(path)
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.runtimepath:append(p)
    package.path = table.concat({
        p .. "/lua/?.lua",
        p .. "/lua/?/init.lua",
        package.path,
      }, ";")
  end
end

add_neovim_plugin("~/.local/share/nvim/lazy/which-key.nvim")
add_neovim_plugin("~/.local/share/nvim/lazy/telescope.nvim")
add_neovim_plugin("~/.local/share/nvim/lazy/plenary.nvim")


local base = project_root .. "/.test_nvim_data"
vim.env.XDG_DATA_HOME   = base .. "/site"
vim.env.XDG_CONFIG_HOME = base .. "/config"
vim.env.XDG_STATE_HOME  = base .. "/state"

package.path = table.concat({
    project_root .. "/?.lua",
    project_root .. "/?/init.lua",
    project_root .. "/lua/?.lua",
    project_root .. "/lua/?/init.lua",
    package.path,
  }, ";")

local ok, tungsten = pcall(require, "tungsten")
if not ok then
  error("Minimal_init FATAL: Failed to require_plugin 'tungsten': " .. tostring(tungsten))
end

if type(tungsten.setup) == "function" then
  tungsten.setup()
end

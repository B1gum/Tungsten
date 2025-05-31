-- tungsten/tests/minimal_init.lua (Setup-Only Version)

local lpeg_instance = require("lpeg")
if package.loaded.lpeg == nil then
  package.loaded.lpeg = lpeg_instance
elseif package.loaded.lpeg ~= lpeg_instance then
  print("Minimal_init WARN: Overwriting pre-existing package.loaded.lpeg.")
  package.loaded.lpeg = lpeg_instance
end

local tungsten_plugin_root
if vim.env.TUNGSTEN_PROJECT_ROOT then
    tungsten_plugin_root = vim.env.TUNGSTEN_PROJECT_ROOT
else
    tungsten_plugin_root = vim.fn.fnamemodify(vim.api.nvim_call_function('expand', {'%:p:h'}), ':h:h')
end
vim.opt.runtimepath:prepend(tungsten_plugin_root)

local collected_lua_paths = {}
table.insert(collected_lua_paths, tungsten_plugin_root .. "/?.lua")
table.insert(collected_lua_paths, tungsten_plugin_root .. "/?/init.lua")
local tungsten_lua_dir = tungsten_plugin_root .. "/lua"
table.insert(collected_lua_paths, tungsten_lua_dir .. "/?.lua")
table.insert(collected_lua_paths, tungsten_lua_dir .. "/?/init.lua")

local function add_plugin_lua_dir_to_paths(plugin_root_path_str, plugin_name)
  local expanded_plugin_root = vim.fn.expand(plugin_root_path_str)
  if vim.fn.isdirectory(expanded_plugin_root) == 1 then
    vim.opt.runtimepath:prepend(expanded_plugin_root)
    local lua_dir_for_plugin = expanded_plugin_root .. "/lua"
    table.insert(collected_lua_paths, lua_dir_for_plugin .. "/?.lua")
    table.insert(collected_lua_paths, lua_dir_for_plugin .. "/?/init.lua")
  else
    local err_msg = "Minimal_init ERROR: " .. plugin_name .. " not found at: " .. expanded_plugin_root .. ". Path: " .. plugin_root_path_str .. ". Tests might fail."
    print(err_msg)
  end
end

add_plugin_lua_dir_to_paths("~/.local/share/nvim/lazy/plenary.nvim", "Plenary.nvim")
add_plugin_lua_dir_to_paths("~/.local/share/nvim/lazy/which-key.nvim", "which-key.nvim")
add_plugin_lua_dir_to_paths("~/.local/share/nvim/lazy/telescope.nvim", "Telescope.nvim")

local test_data_path_base = tungsten_plugin_root .. "/.test_nvim_data"
vim.env.XDG_DATA_HOME = test_data_path_base .. '/site'
vim.env.XDG_CONFIG_HOME = test_data_path_base .. '/config'
vim.env.XDG_STATE_HOME = test_data_path_base .. '/state'

package.path = table.concat(collected_lua_paths, ";") .. ";" .. package.path

local plenary_ok, plenary_mod = pcall(require, 'plenary')
if not plenary_ok then
  local err_msg = "Minimal_init FATAL: Failed to require 'plenary': " .. tostring(plenary_mod)
  print(err_msg)
  error("Plenary could not be loaded. Check runtimepath and package.path setup.")
end

local tungsten_ok, tungsten_main_ns = pcall(require, 'tungsten')
if not tungsten_ok then
    local err_msg = "Minimal_init FATAL: Failed to require Tungsten plugin: " .. tostring(tungsten_main_ns)
    print(err_msg)
else
    if tungsten_main_ns and tungsten_main_ns.setup then
        local setup_ok, setup_err = pcall(tungsten_main_ns.setup)
        if not setup_ok then
            local err_msg = "Minimal_init ERROR: Error during Tungsten setup: " .. tostring(setup_err) .. "\nStacktrace: " .. debug.traceback()
            print(err_msg)
        else
        end
    else
        local warn_msg = "Minimal_init WARN: Tungsten plugin does not have a setup function, or 'require' failed to return the main module properly."
        print(warn_msg)
    end
end

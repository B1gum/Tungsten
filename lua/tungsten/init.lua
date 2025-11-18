-- init.lua
-- Main initiation module for the plugin
--------------------------------------------

local defaults = require("tungsten.config")
local domain_manager = require("tungsten.core.domain_manager")
local M = { config = vim.deepcopy(defaults) }

local function load_backend_module(name)
	if type(name) ~= "string" or name == "" then
		return false, "backend name must be a non-empty string"
	end

	local module_name = "tungsten.backends." .. name
	if package.loaded[module_name] ~= nil then
		return true
	end

	local ok, result = pcall(require, module_name)
	if not ok then
		return false, result
	end

	return true, result
end

M._load_backend_module = load_backend_module

local function execute_hook(name, ...)
	local hooks = M.config.hooks or {}
	local fn = hooks[name]
	local fn_type = type(fn)
	if
		fn_type == "function" or (fn_type == "table" and getmetatable(fn) and type(getmetatable(fn).__call) == "function")
	then
		pcall(fn, ...)
	end
end
M._execute_hook = execute_hook

local function emit_result_event(result)
	if vim and vim.api and vim.api.nvim_exec_autocmds then
		vim.api.nvim_exec_autocmds("User", {
			pattern = "TungstenResult",
			modeline = false,
			data = { result = result },
		})
	end
end
M._emit_result_event = emit_result_event

function M.setup(user_opts)
	if user_opts ~= nil and type(user_opts) ~= "table" then
		error("tungsten.setup: options table expected", 2)
	end

	if user_opts and next(user_opts) then
		M.config = vim.tbl_deep_extend("force", vim.deepcopy(M.config), user_opts)
	end

	M.config.hooks = M.config.hooks or {}

	if type(M.config.domains) == "table" and not vim.tbl_islist(M.config.domains) then
		local registry = require("tungsten.core.registry")
		local domain_names = {}
		for name, prio in pairs(M.config.domains) do
			registry.set_domain_priority(name, prio)
			table.insert(domain_names, name)
		end
		M.config.domains = domain_names
	end

	require("tungsten.util.logger").set_level(M.config.log_level or "INFO")

	package.loaded["tungsten.config"] = M.config

	local backend_manager = require("tungsten.backends.manager")

	local backend_name = M.config.backend
	local backend_opts = {}
	if type(M.config.backend_opts) == "table" then
		backend_opts = M.config.backend_opts[backend_name] or {}
	end

	local backend_loaded, load_err = load_backend_module(backend_name)
	local backend_instance, activate_err = backend_manager.activate(backend_name, backend_opts)
	if not backend_instance then
		local messages = {}
		if not backend_loaded and load_err then
			messages[#messages + 1] = tostring(load_err)
		end
		if activate_err then
			messages[#messages + 1] = tostring(activate_err)
		end
		local final_message = table.concat(messages, " | ")
		if final_message == "" then
			final_message = "Unknown error"
		end
		error(
			string.format("tungsten.setup: failed to activate backend '%s': %s", tostring(backend_name), final_message),
			0
		)
	end

	local state = require("tungsten.state")
	local Cache = require("tungsten.cache")
	state.cache = Cache.new(M.config.cache_max_entries, M.config.cache_ttl)

	require("tungsten.core.commands")
	require("tungsten.ui.which_key")
	require("tungsten.ui.commands")
	require("tungsten.ui")
	require("tungsten.core")

	local registry = require("tungsten.core.registry")
	for _, cmd in ipairs(registry.commands) do
		vim.api.nvim_create_user_command(cmd.name, cmd.func, cmd.opts or { desc = cmd.desc })
	end

	local augroup = vim.api.nvim_create_augroup("TungstenUnload", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = augroup,
		callback = function()
			require("tungsten").teardown()
		end,
	})
end

function M.register_domain(name)
	return domain_manager.register_domain(name)
end

function M.teardown()
	local async = require("tungsten.util.async")
	async.cancel_all_jobs()
	execute_hook("teardown")
end

return M

-- lua/tungsten/core/solver.lua

local ast = require("tungsten.core.ast")
local backend_manager = require("tungsten.backends.manager")

local M = {}

function M.solve_asts_async(eq_asts, var_asts, is_system, callback, opts)
	assert(
		callback and type(eq_asts) == "table" and type(var_asts) == "table",
		"solve_asts_async expects tables and a callback"
	)

	opts = opts or {}
	local backend = opts.backend or backend_manager.current()
	local backend_opts = {}
	for k, v in pairs(opts) do
		if k ~= "backend" then
			backend_opts[k] = v
		end
	end
	backend_opts.is_system = is_system

	if not backend or type(backend.solve_async) ~= "function" then
		callback(nil, "Active backend does not support equation solving")
		return
	end

	local solve_node = ast.create_solve_system_node(eq_asts, var_asts)

	backend.solve_async(solve_node, backend_opts, callback)
end

return M

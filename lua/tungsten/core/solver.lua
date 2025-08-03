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
	opts.is_system = is_system

	local backend = backend_manager.current()
	if not backend or type(backend.solve_async) ~= "function" then
		callback(nil, "Active backend does not support equation solving")
		return
	end

	local solve_node = ast.create_solve_system_node(eq_asts, var_asts)

	backend:solve_async(solve_node, opts, callback)
end

return M

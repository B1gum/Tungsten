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

function M.solve_asts_async(eq_asts, var_asts, is_system, callback)
	assert(
		callback and type(eq_asts) == "table" and type(var_asts) == "table",
		"solve_asts_async expects tables and a callback"
	)

	local eq_strs = {}
	for _, ast_node in ipairs(eq_asts) do
		local ok, str = pcall(wolfram_backend.ast_to_wolfram, ast_node)
		if not ok then
			callback(nil, "Failed to convert an equation to Wolfram string: " .. tostring(str))
			return
		end
		table.insert(eq_strs, str)
	end

	local var_strs = {}
	for _, var_node in ipairs(var_asts) do
		local ok, str = pcall(wolfram_backend.ast_to_wolfram, var_node)
		if not ok then
			callback(nil, "Failed to convert a variable to Wolfram string: " .. tostring(str))
			return
		end
		table.insert(var_strs, str)
	end

	M.solve_equation_async(eq_strs, var_strs, is_system, callback)
end

return M

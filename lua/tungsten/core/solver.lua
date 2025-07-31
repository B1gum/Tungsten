-- lua/tungsten/core/solver.lua

local engine = require("tungsten.core.engine")
local ast = require("tungsten.core.ast")
local wolfram_backend = require("tungsten.backends.wolfram")
local solution_helper = require("tungsten.backends.wolfram.wolfram_solution")

local M = {}

function M.solve_asts_async(eq_asts, var_asts, is_system, callback)
	assert(
		callback and type(eq_asts) == "table" and type(var_asts) == "table",
		"solve_asts_async expects tables and a callback"
	)

	local var_strs = {}
	for _, var_node in ipairs(var_asts) do
		local ok, str = pcall(wolfram_backend.ast_to_wolfram, var_node)
		if not ok then
			callback(nil, "Failed to convert a variable to Wolfram string: " .. tostring(str))
			return
		end
		table.insert(var_strs, str)
	end

	local solve_node = ast.create_solve_system_node(eq_asts, var_asts)

	engine.evaluate_async(solve_node, { is_system = is_system }, function(result, err)
		if err then
			callback(nil, err)
			return
		end

		local parsed = solution_helper.parse_wolfram_solution(result, var_strs, is_system)
		if parsed.ok then
			callback(parsed.formatted, nil)
		else
			callback(nil, parsed.reason)
		end
	end)
end

return M

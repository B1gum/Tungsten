local M = {}

function M.find_free_variables(node)
	local free_vars = require("tungsten.domains.plotting.free_vars")
	return free_vars.find(node)
end

function M.union_vars(...)
	local set = {}
	local result = {}
	for _, vars in ipairs({ ... }) do
		for _, v in ipairs(vars) do
			if not set[v] then
				set[v] = true
				table.insert(result, v)
			end
		end
	end
	table.sort(result)
	return result
end

function M.remove_var(vars, name)
	local removed = false
	for i = #vars, 1, -1 do
		if vars[i] == name then
			table.remove(vars, i)
			removed = true
		end
	end
	return removed
end

return M

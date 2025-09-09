-- Stub out free variable analysis to keep the tests self contained.
local function collect_vars(node, acc)
	acc = acc or {}
	if type(node) ~= "table" then
		return acc
	end
	if node.type == "variable" and node.name then
		acc[node.name] = true
	elseif node.type == "binary_op" then
		collect_vars(node.left, acc)
		collect_vars(node.right, acc)
	end
	return acc
end

package.loaded["tungsten.domains.plotting.free_vars"] = {
	find = function(node)
		local set = collect_vars(node)
		local vars = {}
		for name in pairs(set) do
			table.insert(vars, name)
		end
		table.sort(vars)
		return vars
	end,
}

local classification = require("tungsten.domains.plotting.classification")

describe("plot classification", function()
	it("classifies single-variable expressions as 2D explicit", function()
		local ast = { type = "variable", name = "x" }
		local result = classification.analyze(ast)
		assert.are.same(2, result.dim)
		assert.are.same("explicit", result.form)
	end)

	it("classifies two-variable expressions as 3D explicit", function()
		local ast = {
			type = "binary_op",
			operator = "+",
			left = { type = "variable", name = "x" },
			right = { type = "variable", name = "y" },
		}
		local result = classification.analyze(ast)
		assert.are.same(3, result.dim)
		assert.are.same("explicit", result.form)
	end)
end)

local stub = require("luassert.stub")
local python_plot = require("tungsten.backends.python.plot_generator")
local executor = require("tungsten.backends.python.executor")

describe("python plot points", function()
	local ast_stub

	before_each(function()
		ast_stub = stub(executor, "ast_to_code", function(node)
			if type(node) == "table" and node.__code then
				return node.__code
			end
			return "expr"
		end)
	end)

	after_each(function()
		if ast_stub then
			ast_stub:revert()
			ast_stub = nil
		end
	end)

	it("emits scatter commands for explicit point series", function()
		local opts = {
			dim = 2,
			form = "explicit",
			xrange = { -3, 3 },
			series = {
				{
					kind = "function",
					ast = { __code = "x" },
					independent_vars = { "x" },
					dependent_vars = { "y" },
				},
				{
					kind = "points",
					points = {
						{ x = { __code = "-2" }, y = { __code = "-2" } },
						{ x = { __code = "0" }, y = { __code = "0" } },
						{ x = { __code = "2" }, y = { __code = "2" } },
					},
				},
			},
		}

		local code, err = python_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("ax.scatter", 1, true))
		assert.is_truthy(code:find("-2", 1, true))
	end)
end)

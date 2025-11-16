local stub = require("luassert.stub")
local plot_backend = require("tungsten.backends.python.plot")
local executor = require("tungsten.backends.python.executor")

describe("python polar plotting", function()
	local ast_stub

	before_each(function()
		ast_stub = stub(executor, "ast_to_code", function(ast)
			if type(ast) == "table" and ast.__code then
				return ast.__code
			end
			return "expr"
		end)
	end)

	after_each(function()
		if ast_stub then
			ast_stub:revert()
		end
	end)

	it("builds theta samples for polar plots", function()
		local opts = {
			dim = 2,
			form = "polar",
			theta_range = { 0, "2*np.pi" },
			samples = 180,
			series = {
				{
					kind = "function",
					ast = { r = { __code = "theta + 1" } },
					independent_vars = { "theta" },
				},
			},
		}

		local code, _, err = plot_backend.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("theta_vals = np.linspace(0, 2*np.pi, 180)", 1, true))
		assert.is_truthy(code:find("ax.plot(theta_vals, f1(theta_vals))", 1, true))
	end)

	it("uses a polar axis when building scripts", function()
		local opts = {
			dim = 2,
			form = "polar",
			theta_range = { 0, "2*np.pi" },
			samples = 90,
			out_path = "polar.png",
			series = {
				{
					kind = "function",
					ast = { r = { __code = "theta" } },
					independent_vars = { "theta" },
				},
			},
		}

		local script, err = plot_backend.build_python_script(opts)
		assert.is_nil(err)
		assert.is_truthy(script:find("projection='polar'", 1, true))
	end)
end)

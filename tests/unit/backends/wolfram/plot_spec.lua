local stub = require("luassert.stub")
local wolfram_plot = require("tungsten.backends.wolfram.plot")
local executor = require("tungsten.backends.wolfram.executor")
local async = require("tungsten.util.async")

describe("wolfram polar plotting", function()
	local ast_stub
	local async_stub

	after_each(function()
		if ast_stub then
			ast_stub:revert()
			ast_stub = nil
		end
		if async_stub then
			async_stub:revert()
			async_stub = nil
		end
	end)

	it("builds a PolarPlot command with sampling, styles, and legends", function()
		ast_stub = stub(executor, "ast_to_code", function(ast)
			if type(ast) == "table" and ast.__code then
				return ast.__code
			end
			return "expr"
		end)

		local captured_code
		async_stub = stub(async, "run_job", function(cmd, opts)
			captured_code = cmd[3]
			if opts and opts.on_exit then
				opts.on_exit(0, "ok", "")
			end
		end)

		local callback_called = false
		wolfram_plot.plot_async({
			out_path = "polar.png",
			dim = 2,
			form = "polar",
			theta_range = { 0, "2*Pi" },
			samples = 180,
			figsize_in = { 4, 4 },
			legend_auto = false,
			legend_pos = "upper right",
			series = {
				{
					kind = "function",
					ast = { r = { __code = "1 + Cos[theta]" } },
					independent_vars = { "theta" },
					label = "Cardioid",
					color = "Red",
				},
			},
		}, function(err)
			assert.is_nil(err)
			callback_called = true
		end)

		assert.is_true(callback_called)
		assert.is_truthy(captured_code)
		assert.is_truthy(captured_code:find("PolarPlot[1 + Cos[theta], {theta, 0, 2*Pi}", 1, true))
		assert.is_truthy(captured_code:find("PlotPoints -> 180", 1, true))
		assert.is_truthy(captured_code:find("ImageSize -> {288, 288}", 1, true))
		assert.is_truthy(captured_code:find("PlotStyle -> Directive[Red]", 1, true))
		assert.is_truthy(captured_code:find('PlotLegends -> Placed[{"Cardioid"}, Scaled[{1, 1}]]', 1, true))
	end)
end)

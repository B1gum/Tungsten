local stub = require("luassert.stub")
local wolfram_plot = require("tungsten.backends.wolfram.plot")
local executor = require("tungsten.backends.wolfram.executor")
local async = require("tungsten.util.async")

local function build_base_opts(overrides)
	local opts = {
		dim = 2,
		form = "explicit",
		xrange = { -5, 5 },
		series = {
			{
				kind = "function",
				ast = { __code = "x^2" },
				independent_vars = { "x" },
				dependent_vars = { "y" },
			},
		},
	}
	for k, v in pairs(overrides or {}) do
		opts[k] = v
	end
	return opts
end

describe("wolfram plot option translation", function()
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
			ast_stub = nil
		end
	end)

	it("omits PlotRange when no clipping is requested", function()
		local code, err = wolfram_plot.build_plot_code(build_base_opts())
		assert.is_nil(err)
		assert.is_truthy(code:match("^Plot%["))
		assert.is_nil(code:match("PlotRange"))
	end)

	it("includes PlotRange when dependent axes are clipped", function()
		local opts = build_base_opts({ clip_dependent_axes = true, yrange = { -2, 2 } })
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:match("PlotRange"))
		assert.is_truthy(code:match("%{-2, 2%}"))
	end)

	it("respects explicit axis clipping overrides", function()
		local opts = build_base_opts({ clip_axes = { x = true } })
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:match("PlotRange"))
		assert.is_truthy(code:match("%{-5, 5%}"))
	end)

	it("uses the matching axis range for x = f(y) plots", function()
		local opts = build_base_opts({
			xrange = { -1, 1 },
			yrange = { -3, 3 },
			clip_axes = { x = true, y = true },
		})
		opts.series[1].independent_vars = { "y" }
		opts.series[1].dependent_vars = { "x" }
		opts.series[1].ast = {
			type = "equality",
			rhs = { __code = "y^2" },
		}
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("Plot[", 1, true))
		assert.is_truthy(code:find("{y, -3, 3}", 1, true))
		assert.is_truthy(code:find("PlotRange -> {{-3, 3}, {-1, 1}}", 1, true))
	end)

	it("maps ranges to the correct axes for y = f(x, z)", function()
		local opts = {
			form = "explicit",
			dim = 3,
			xrange = { -1, 1 },
			yrange = { -2, 2 },
			zrange = { -4, 4 },
			clip_axes = { x = true, y = true, z = true },
			series = {
				{
					kind = "function",
					ast = { __code = "x^2 + z" },
					independent_vars = { "x", "z" },
					dependent_vars = { "y" },
				},
			},
		}
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("Plot3D", 1, true))
		assert.is_truthy(code:find("{x, -1, 1}", 1, true))
		assert.is_truthy(code:find("{z, -4, 4}", 1, true))
		assert.is_truthy(code:find("PlotRange -> {{-1, 1}, {-4, 4}, {-2, 2}}", 1, true))
	end)
end)

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

	describe("wolfram implicit plotting styles", function()
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
				ast_stub = nil
			end
		end)

		local function build_base_opts(overrides)
			local opts = {
				form = "implicit",
				dim = 2,
				xrange = { 0, 1 },
				yrange = { 0, 1 },
				series = {
					{
						kind = "inequality",
						ast = { __code = "x > y" },
						independent_vars = { "x", "y", "z" },
					},
				},
			}
			for k, v in pairs(overrides or {}) do
				opts[k] = v
			end
			return opts
		end

		it("applies default opacity to inequality series", function()
			local code, err = wolfram_plot.build_plot_code(build_base_opts())
			assert.is_nil(err)
			assert.is_truthy(code:find("Opacity[0.4]", 1, true))
		end)

		it("does not override explicit alpha on inequality series", function()
			local opts = build_base_opts()
			opts.series[1].alpha = 0.9
			local code, err = wolfram_plot.build_plot_code(opts)
			assert.is_nil(err)
			assert.is_nil(code:find("Opacity[0.4]", 1, true))
			assert.is_truthy(code:find("Opacity[0.9]", 1, true))
		end)

		it("suppresses RegionPlot3D boundaries to highlight volume", function()
			local opts = build_base_opts({ dim = 3, zrange = { 0, 1 } })
			local code, err = wolfram_plot.build_plot_code(opts)
			assert.is_nil(err)
			assert.is_truthy(code:find("RegionPlot3D", 1, true))
			assert.is_truthy(code:find("BoundaryStyle -> None", 1, true))
		end)

		it("suppresses ContourPlot3D mesh outlines", function()
			local opts = {
				form = "implicit",
				dim = 3,
				xrange = { 0, 1 },
				yrange = { 0, 1 },
				zrange = { 0, 1 },
				series = {
					{
						kind = "function",
						ast = { __code = "x^2 + y^2 + z^2" },
						independent_vars = { "x", "y", "z" },
					},
				},
			}
			local code, err = wolfram_plot.build_plot_code(opts)
			assert.is_nil(err)
			assert.is_truthy(code:find("ContourPlot3D", 1, true))
			assert.is_truthy(code:find("Mesh -> None", 1, true))
		end)
	end)
end)

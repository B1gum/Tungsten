local stub = require("luassert.stub")
local wolfram_plot = require("tungsten.backends.wolfram.plot_generator")
local executor = require("tungsten.backends.wolfram.executor")
local async = require("tungsten.util.async")
local ast_core = require("tungsten.core.ast")

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

	it("normalizes common style names for directives", function()
		local opts = build_base_opts({
			series = {
				{
					kind = "function",
					ast = { __code = "Sin[x]" },
					independent_vars = { "x" },
					dependent_vars = { "y" },
					color = "red",
					linewidth = 2,
					linestyle = "dashed",
				},
			},
		})

		local code, err = wolfram_plot.build_plot_code(opts)

		assert.is_nil(err)
		assert.is_truthy(code:find("PlotStyle%s*->%s*Directive%[Red,%s*AbsoluteThickness%[2%],%s*Dashed%]"))
	end)

	it("omits PlotMarkers when markers are disabled", function()
		local opts = build_base_opts()
		opts.series[1].marker = "none"
		opts.series[1].markersize = "6"

		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_nil(code:match("PlotMarkers"))
	end)

	it("omits PlotMarkers for explicit function plots", function()
		local opts = build_base_opts()
		opts.series[1].marker = "o"
		opts.series[1].markersize = "3"

		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_nil(code:match("PlotMarkers"))
	end)

	it("inserts PlotLegends for labeled explicit function plots", function()
		local opts = build_base_opts({
			legend_auto = true,
			series = {
				{
					kind = "function",
					ast = { __code = "Sin[x]" },
					independent_vars = { "x" },
					dependent_vars = { "y" },
					label = "sin(x)",
				},
				{
					kind = "function",
					ast = { __code = "Cos[x]" },
					independent_vars = { "x" },
					dependent_vars = { "y" },
					label = "cos(x)",
				},
			},
		})

		local code, err = wolfram_plot.build_plot_code(opts)

		assert.is_nil(err)
		assert.is_truthy(code:find('PlotLegends -> {"sin(x)", "cos(x)"}', 1, true), code)
	end)

	it("places legends for explicit point plots", function()
		local opts = build_base_opts({
			legend_auto = false,
			legend_pos = "ne",
			series = {
				{
					kind = "points",
					label = "Samples",
					points = {
						{ x = { __code = "0" }, y = { __code = "0" } },
						{ x = { __code = "1" }, y = { __code = "1" } },
					},
				},
			},
		})

		local code, err = wolfram_plot.build_plot_code(opts)

		assert.is_nil(err)
		assert.is_truthy(code:find('PlotLegends -> Placed[{"Samples"}, Scaled[{1, 1}]]', 1, true), code)
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

	it("keeps axis order when only dependent axes are clipped", function()
		local opts = build_base_opts({ clip_axes = { y = true }, yrange = { -2, 2 } })
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("PlotRange -> {Automatic, {-2, 2}}", 1, true))
	end)

	it("resolves alias ranges for independent variables", function()
		local opts = build_base_opts({
			xrange = { -2, 2 },
			yrange = { -1, 1 },
			clip_axes = { t = "x", x = true },
		})
		opts.series[1].independent_vars = { "t" }
		opts.series[1].dependent_vars = { "y" }
		opts.series[1].ast = { __code = "t^2" }

		local code, err = wolfram_plot.build_plot_code(opts)

		assert.is_nil(err)
		assert.is_truthy(code:find("{t, -2, 2}", 1, true))
		assert.is_truthy(code:find("PlotRange -> {{-2, 2}, Automatic}", 1, true))
	end)

	it("ignores figsize_in and defers to Wolfram defaults", function()
		local opts = build_base_opts({
			clip_axes = { y = true },
			yrange = { -2, 2 },
			figsize_in = { width = 5, height = 3 },
		})
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_nil(code:match("ImageSize"))
	end)

	it("omits AspectRatio overrides when aspect is auto", function()
		local opts = build_base_opts({ aspect = "auto" })
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_nil(code:match("AspectRatio"))
	end)

	it("overlays explicit plots with point collections", function()
		local opts = build_base_opts()
		opts.series[#opts.series + 1] = {
			kind = "points",
			points = {
				{ x = { __code = "-2" }, y = { __code = "-2" } },
				{ x = { __code = "0" }, y = { __code = "0" } },
				{ x = { __code = "2" }, y = { __code = "2" } },
			},
		}

		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("Show[{", 1, true), code)
		assert.is_truthy(code:find("ListPlot", 1, true), code)
		assert.is_truthy(code:find("{-2, -2}", 1, true), code)
	end)

	it("emits AspectRatio -> 1 when aspect is equal", function()
		local opts = build_base_opts({ aspect = "equal" })
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("AspectRatio -> 1", 1, true))
	end)

	it("emits BoxRatios -> {1,1,1} when 3D aspect is equal", function()
		local opts = {
			form = "explicit",
			dim = 3,
			aspect = "equal",
			xrange = { -1, 1 },
			yrange = { -2, 2 },
			zrange = { -3, 3 },
			series = {
				{
					kind = "function",
					ast = { __code = "x^2 + y^2" },
					independent_vars = { "x", "y" },
					dependent_vars = { "z" },
				},
			},
		}

		local code, err = wolfram_plot.build_plot_code(opts)

		assert.is_nil(err)
		assert.is_truthy(code:find("BoxRatios -> {1,1,1}", 1, true))
	end)

	it("adds GridLines when grids are enabled for 2D plots", function()
		local opts = build_base_opts({ grids = true })
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("GridLines -> Automatic", 1, true))
	end)

	it("unwraps Equality nodes before rendering explicit plots", function()
		ast_stub:revert()
		local equality_error = "Equality node leaked to renderer"
		ast_stub = stub(executor, "ast_to_code", function(ast)
			if type(ast) == "table" and ast.type == "Equality" then
				error(equality_error)
			end
			if type(ast) == "table" and ast.__code then
				return ast.__code
			end
			return "expr"
		end)

		local opts = build_base_opts()
		opts.series[1].ast = { type = "Equality", rhs = { __code = "2*x" } }

		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("Plot[2*x", 1, true))
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

	it("pads un-clipped axes with Automatic in 3D plots", function()
		local opts = {
			form = "explicit",
			dim = 3,
			xrange = { -1, 1 },
			yrange = { -2, 2 },
			zrange = { -4, 4 },
			clip_axes = { z = true },
			series = {
				{
					kind = "function",
					ast = { __code = "x^2 + y" },
					independent_vars = { "x", "y" },
					dependent_vars = { "z" },
				},
			},
		}
		local code, err = wolfram_plot.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("Plot3D", 1, true))
		assert.is_truthy(code:find("PlotRange -> {Automatic, Automatic, {-4, 4}}", 1, true))
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
		assert.is_nil(captured_code:match("ImageSize"))
		assert.is_truthy(captured_code:find("PlotStyle -> Directive[Red]", 1, true))
		assert.is_truthy(captured_code:find('PlotLegends -> Placed[{"Cardioid"}, Scaled[{1, 1}]]', 1, true))
	end)

	describe("wolfram implicit plotting styles", function()
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

		local function build_base_opts2(overrides)
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
			local code, err = wolfram_plot.build_plot_code(build_base_opts2())
			assert.is_nil(err)
			assert.is_truthy(code:find("Opacity[0.4]", 1, true))
		end)

		it("does not override explicit alpha on inequality series", function()
			local opts = build_base_opts2()
			opts.series[1].alpha = 0.9
			local code, err = wolfram_plot.build_plot_code(opts)
			assert.is_nil(err)
			assert.is_nil(code:find("Opacity[0.4]", 1, true))
			assert.is_truthy(code:find("Opacity[0.9]", 1, true))
		end)

		it("suppresses RegionPlot3D boundaries to highlight volume", function()
			local opts = build_base_opts2({ dim = 3, zrange = { 0, 1 } })
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

		it("uses ContourStyle with automatic colors for 3D contours", function()
			local opts = {
				form = "implicit",
				dim = 3,
				xrange = { -1, 1 },
				yrange = { -2, 2 },
				zrange = { -3, 3 },
				plot_points = 30,
				max_recursion = 2,
				series = {
					{
						kind = "function",
						ast = { __code = "x^2 + y^2 + z^2" },
						independent_vars = { "x", "y", "z" },
						color = "auto",
						linewidth = 1.5,
						alpha = 1,
					},
				},
			}

			local code, err = wolfram_plot.build_plot_code(opts)
			assert.is_nil(err)
			assert.is_truthy(code:find("ContourPlot3D", 1, true))
			assert.is_truthy(
				code:match("ContourStyle%s*->%s*Directive%[Automatic,%s*AbsoluteThickness%[1%.5%],%s*Opacity%[1%]%]")
			)
			assert.is_nil(code:match("PlotStyle%s*->"))
		end)
	end)
end)

describe("wolfram plot ranges", function()
	it("converts latex constants in range endpoints", function()
		local sin_ast = ast_core.create_function_call_node(ast_core.create_variable_node("sin"), {
			ast_core.create_variable_node("x"),
		})

		local code = assert(wolfram_plot.build_plot_code({
			form = "explicit",
			dim = 2,
			xrange = { "-\\pi", "\\pi" },
			series = {
				{
					kind = "function",
					ast = sin_ast,
					independent_vars = { "x" },
				},
			},
			legend_auto = true,
		}))

		assert.is_true(code:find("{x, -Pi, Pi}", 1, true) ~= nil)
	end)

	it("normalizes latex multiplication in parametric ranges", function()
		local stub_ast = stub(executor, "ast_to_code", function(node)
			if type(node) == "table" and node.__code then
				return node.__code
			end
			return "expr"
		end)

		local code = assert(wolfram_plot.build_plot_code({
			form = "parametric",
			dim = 2,
			t_range = { "0", "2\\cdot \\pi" },
			series = {
				{
					kind = "function",
					ast = {
						x = { __code = "Cos[t]" },
						y = { __code = "Sin[t]" },
					},
					independent_vars = { "t" },
					dependent_vars = { "x", "y" },
				},
			},
		}))

		stub_ast:revert()

		assert.is_true(code:find("{t, 0, 2%*%s*Pi}") ~= nil, code)
	end)

	it("renders parsed expressions in plot range endpoints", function()
		local integral_ast = ast_core.create_definite_integral_node(
			ast_core.create_variable_node("x"),
			ast_core.create_variable_node("x"),
			ast_core.create_number_node(0),
			ast_core.create_number_node(1)
		)

		local stub_ast = stub(executor, "ast_to_code", function(node)
			if node == integral_ast then
				return "Integrate[x, {x, 0, 1}]"
			end
			if type(node) == "table" and node.__code then
				return node.__code
			end
			return "expr"
		end)

		local code, _, err = wolfram_plot.build_plot_code({
			form = "parametric",
			dim = 2,
			t_range = { integral_ast, { __code = "2" } },
			series = {
				{
					kind = "function",
					ast = {
						x = { __code = "Cos[t]" },
						y = { __code = "Sin[t]" },
					},
					independent_vars = { "t" },
					dependent_vars = { "x", "y" },
				},
			},
		})

		assert.is_nil(err, err and (err.message or err.code or err) or err)
		assert.is_not_nil(code)

		assert.is_truthy(code:find("{t,%s*Integrate%[x,%s*{%s*x,%s*0,%s*1%s*}%],%s*2%}") ~= nil, code)

		stub_ast:revert()
	end)
end)

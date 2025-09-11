-- Unit tests for the plotting options builder and default values, ensuring
-- adherence to the v1 specification.

local mock_utils = require("tests.helpers.mock_utils")
local spy = require("luassert.spy")

describe("Plotting Options and Defaults", function()
	local options_builder
	local mock_config

	local modules_to_reset = {
		"tungsten.domains.plotting.options_builder",
		"tungsten.config",
	}

	before_each(function()
		mock_utils.reset_modules(modules_to_reset)

		mock_config = {
			plotting = {
				usetex = true,
				latex_engine = "pdflatex",
				latex_preamble = "",
				default_xrange = { -10, 10 },
				default_yrange = { -10, 10 },
				default_zrange = { -10, 10 },
				default_t_range = { -10, 10 },
				default_theta_range = { 0, "2*pi" },
				default_urange = { -10, 10 },
				default_vrange = { -10, 10 },
			},
		}

		package.loaded["tungsten.config"] = mock_config

		options_builder = require("tungsten.domains.plotting.options_builder")
	end)

	after_each(function()
		mock_utils.reset_modules(modules_to_reset)
	end)

	it("constructs a basic options table", function()
		local opts = options_builder.build({ dim = 2, form = "explicit" }, {})
		assert.is_table(opts)
		assert.are.same({ -10, 10 }, opts.xrange)
	end)

	describe("Default Ranges", function()
		it("applies defaults based on dimension and form", function()
			local exp2 = options_builder.build({ dim = 2, form = "explicit" }, {})
			assert.are.same({ -10, 10 }, exp2.xrange)
			assert.is_nil(exp2.yrange)

			local exp3 = options_builder.build({ dim = 3, form = "explicit" }, {})
			assert.are.same({ -10, 10 }, exp3.xrange)
			assert.are.same({ -10, 10 }, exp3.yrange)
			assert.is_nil(exp3.zrange)

			local imp2 = options_builder.build({ dim = 2, form = "implicit" }, {})
			assert.are.same({ -10, 10 }, imp2.xrange)
			assert.are.same({ -10, 10 }, imp2.yrange)

			local imp3 = options_builder.build({ dim = 3, form = "implicit" }, {})
			assert.are.same({ -10, 10 }, imp3.xrange)
			assert.are.same({ -10, 10 }, imp3.yrange)
			assert.are.same({ -10, 10 }, imp3.zrange)

			local para2 = options_builder.build({ dim = 2, form = "parametric" }, {})
			assert.are.same({ -10, 10 }, para2.t_range)

			local para3 = options_builder.build({ dim = 3, form = "parametric" }, {})
			assert.are.same({ -10, 10 }, para3.u_range)
			assert.are.same({ -10, 10 }, para3.v_range)

			local polar = options_builder.build({ dim = 2, form = "polar" }, {})
			assert.are.same({ 0, "2*pi" }, polar.theta_range)
		end)
	end)

	describe("Styling Defaults", function()
		it("sets defaults for figure styling", function()
			local exp2 = options_builder.build({ dim = 2, form = "explicit" }, {})
			assert.are.same("auto", exp2.aspect)
			assert.are.same({ 6, 4 }, exp2.figsize_in)
			assert.is_nil(exp2.view_elev)
			assert.is_nil(exp2.view_azim)

			local imp2 = options_builder.build({ dim = 2, form = "implicit" }, {})
			assert.are.same("equal", imp2.aspect)
			assert.are.same({ 6, 6 }, imp2.figsize_in)

			local exp3 = options_builder.build({ dim = 3, form = "explicit" }, {})
			assert.are.same("equal", exp3.aspect)
			assert.are.same({ 6, 6 }, exp3.figsize_in)
			assert.are.same(30, exp3.view_elev)
			assert.are.same(-60, exp3.view_azim)

			assert.are.same("viridis", exp2.colormap)
			assert.is_false(exp2.colorbar)
			assert.are.same("white", exp2.bg_color)
		end)

		it("parses style tokens for each series", function()
			local classification = {
				dim = 2,
				form = "explicit",
				series = {
					{
						kind = "function",
						style_tokens = {
							"color=red",
							"linewidth=3",
							"linestyle=--",
							"marker=x",
							"markersize=4",
							"alpha=0.5",
						},
					},
				},
			}
			local opts = options_builder.build(classification, {})
			local s = opts.series[1]
			assert.are.same("red", s.color)
			assert.are.same(3, s.linewidth)
			assert.are.same("--", s.linestyle)
			assert.are.same("x", s.marker)
			assert.are.same(4, s.markersize)
			assert.are.same(0.5, s.alpha)
		end)
	end)

	it("allows overrides to replace defaults", function()
		local opts = options_builder.build(
			{ dim = 2, form = "explicit" },
			{ xrange = { -5, 5 }, aspect = "equal", colorbar = true }
		)
		assert.are.same({ -5, 5 }, opts.xrange)
		assert.are.same("equal", opts.aspect)
		assert.is_true(opts.colorbar)
	end)

	describe("Python backend downgrade", function()
		it("downgrades unsupported 3D explicit plots to 2D and warns", function()
			local classification = {
				dim = 3,
				form = "explicit",
				series = {
					{ dependent_vars = { "z" }, independent_vars = { "x" } },
				},
			}

			local logger = require("tungsten.util.logger")
			local warn_spy = spy.on(logger, "warn")

			local opts = options_builder.build(classification, { backend = "python" })

			assert.are.equal(2, classification.dim)
			assert.are.same({ "z" }, classification.series[1].dependent_vars)
			assert.are.equal(2, opts.dim)
			assert.is_nil(opts.yrange)
			assert.are.same(500, opts.samples)
			assert.spy(warn_spy).was.called(1)

			warn_spy:revert()
		end)
	end)

	describe("LaTeX configuration", function()
		it("uses config defaults and reflects changes", function()
			local defaults = options_builder.build({ dim = 2, form = "explicit" }, {})
			assert.is_true(defaults.usetex)
			assert.are.same("pdflatex", defaults.latex_engine)
			assert.are.same("", defaults.latex_preamble)

			mock_config.plotting.usetex = false
			mock_config.plotting.latex_engine = "lualatex"
			mock_config.plotting.latex_preamble = "\\usepackage{amsmath}"

			local updated = options_builder.build({ dim = 2, form = "explicit" }, {})
			assert.is_false(updated.usetex)
			assert.are.same("lualatex", updated.latex_engine)
			assert.are.same("\\usepackage{amsmath}", updated.latex_preamble)
		end)
	end)
end)

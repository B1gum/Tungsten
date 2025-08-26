-- Unit tests for the plotting options builder and default values, ensuring
-- adherence to the v1 specification.

local mock_utils = require("tests.helpers.mock_utils")

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
				default_xrange = { -10, 10 },
				default_yrange = { -10, 10 },
				default_zrange = { -10, 10 },
				default_trange = { -10, 10 },
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

	it("should construct an options table with all necessary keys for a basic plot", function()
		local classification = { dim = 2, form = "explicit" }
		local opts = options_builder.build(classification, {})

		assert.is_table(opts)
		assert.has_key(opts, "backend")
		assert.has_key(opts, "dim")
		assert.has_key(opts, "form")
		assert.has_key(opts, "series")
		assert.has_key(opts, "xrange")
		assert.has_key(opts, "format")
		assert.has_key(opts, "grids")
		assert.has_key(opts, "aspect")
		assert.has_key(opts, "figsize_in")
		assert.has_key(opts, "legend_auto")
		assert.has_key(opts, "usetex")
		assert.has_key(opts, "timeout_ms")
	end)

	describe("Default Ranges", function()
		it("should set default axis ranges to [-10, 10] if unspecified", function()
			local classification = { dim = 3, form = "explicit" }
			local opts = options_builder.build(classification, {})
			assert.are.same({ -10, 10 }, opts.xrange)
			assert.are.same({ -10, 10 }, opts.yrange)
			assert.are.same({ -10, 10 }, opts.zrange)
		end)

		it("should set correct defaults for parametric and polar plots", function()
			local para_opts = options_builder.build({ dim = 2, form = "parametric" }, {})
			assert.are.same({ -10, 10 }, para_opts.t_range)

			local polar_opts = options_builder.build({ dim = 2, form = "polar" }, {})
			assert.are.same({ 0, "2*pi" }, polar_opts.theta_range)
		end)
	end)

	describe("2D Plot Defaults", function()
		it("should apply correct defaults for a 2D explicit plot", function()
			local classification = { dim = 2, form = "explicit" }
			local opts = options_builder.build(classification, {})

			assert.are.equal("pdf", opts.format)
			assert.are.equal(500, opts.samples)
			assert.are.equal("auto", opts.aspect)
			assert.are.same({ 6, 4 }, opts.figsize_in)
			assert.is_true(opts.grids)
		end)

		it("should apply correct defaults for a 2D implicit plot", function()
			local classification = { dim = 2, form = "implicit" }
			local opts = options_builder.build(classification, {})

			assert.are.equal("pdf", opts.format)
			assert.are.equal(200, opts.grid_n)
			assert.are.equal("equal", opts.aspect)
			assert.are.same({ 6, 6 }, opts.figsize_in)
		end)

		it("should apply correct sampling defaults for 2D parametric and polar plots", function()
			local para_opts = options_builder.build({ dim = 2, form = "parametric" }, {})
			assert.are.equal(300, para_opts.samples)

			local polar_opts = options_builder.build({ dim = 2, form = "polar" }, {})
			assert.are.equal(360, polar_opts.samples)
		end)
	end)

	describe("3D Plot Defaults", function()
		it("should apply correct defaults for a 3D explicit plot", function()
			local classification = { dim = 3, form = "explicit" }
			local opts = options_builder.build(classification, {})

			assert.are.equal("png", opts.format)
			assert.are.equal(180, opts.dpi)
			assert.are.same({ 100, 100 }, opts.grid_2d)
			assert.are.equal("equal", opts.aspect)
			assert.are.same({ 6, 6 }, opts.figsize_in)
			assert.is_true(opts.grids)
			assert.are.equal(30, opts.view_elev)
			assert.are.equal(-60, opts.view_azim)
		end)

		it("should apply correct sampling for a 3D parametric plot", function()
			local classification = { dim = 3, form = "parametric" }
			local opts = options_builder.build(classification, {})
			assert.are.same({ 64, 64 }, opts.grid_3d)
		end)

		it("should use coarse sampling defaults for 3D implicit plots", function()
			local classification = { dim = 3, form = "implicit" }
			local opts = options_builder.build(classification, {})
			assert.are.same({ 30, 30, 30 }, opts.vol_3d)
		end)
	end)

	describe("General Defaults and Overrides", function()
		it("should crop output images tightly by default", function()
			local opts = options_builder.build({ dim = 2, form = "explicit" }, {})
			assert.is_true(opts.crop)
		end)

		it("should allow user options to override defaults completely", function()
			local classification = { dim = 2, form = "explicit" }
			local user_overrides = {
				xrange = { -5, 5 },
				samples = 1000,
				format = "svg",
				grids = false,
				aspect = "equal",
			}
			local opts = options_builder.build(classification, user_overrides)

			assert.are.same({ -5, 5 }, opts.xrange)
			assert.are.equal(1000, opts.samples)
			assert.are.equal("svg", opts.format)
			assert.is_false(opts.grids)
			assert.are.equal("equal", opts.aspect)
		end)

		it("should handle partial overrides without discarding other defaults", function()
			local classification = { dim = 3, form = "explicit" }
			local user_overrides = {
				dpi = 300,
				view_azim = -45,
			}
			local opts = options_builder.build(classification, user_overrides)

			assert.are.equal(300, opts.dpi)
			assert.are.equal(-45, opts.view_azim)
			assert.are.equal(30, opts.view_elev)
			assert.are.same({ 100, 100 }, opts.grid_2d)
			assert.are.equal("png", opts.format)
		end)

		it("should correctly handle nil or empty user overrides table", function()
			local classification = { dim = 2, form = "explicit" }
			local opts_with_empty = options_builder.build(classification, {})
			local opts_with_nil = options_builder.build(classification, nil)

			assert.are.same(opts_with_empty, opts_with_nil)
			assert.are.equal(500, opts_with_nil.samples)
		end)
	end)
end)

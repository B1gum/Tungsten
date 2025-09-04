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

	it("allows overrides to replace defaults", function()
		local opts = options_builder.build({ dim = 2, form = "explicit" }, { xrange = { -5, 5 } })
		assert.are.same({ -5, 5 }, opts.xrange)
	end)
end)

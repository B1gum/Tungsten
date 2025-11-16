local mock_utils = require("tests.helpers.mock_utils")
local error_handler = require("tungsten.util.error_handler")

describe("wolfram plot error translation", function()
	local plot

	before_each(function()
		mock_utils.reset_modules({
			"tungsten.backends.wolfram.plot",
			"tungsten.backends.wolfram",
		})
		package.loaded["tungsten.backends.plot_base"] = {}
		package.loaded["tungsten.util.logger"] = {
			debug = function() end,
			error = function() end,
			warn = function() end,
		}
		package.loaded["tungsten.util.async"] = { run_job = function() end }
		package.loaded["tungsten.config"] = {}
		package.loaded["tungsten.backends.wolfram.executor"] = {
			ast_to_code = function()
				return ""
			end,
		}
		plot = require("tungsten.backends.wolfram.plot")
	end)

	after_each(function()
		mock_utils.reset_modules({
			"tungsten.backends.wolfram.plot",
			"tungsten.backends.wolfram",
			"tungsten.backends.plot_base",
			"tungsten.util.logger",
			"tungsten.util.async",
			"tungsten.config",
			"tungsten.backends.wolfram.executor",
		})
	end)

	it("maps ContourPlot::cpcon errors to E_NO_CONTOUR", function()
		local stderr = [=[ContourPlot::cpcon: No contour specified. >]=]
		local result = plot.translate_plot_error(1, "", stderr)
		assert.are.equal(error_handler.E_NO_CONTOUR, result.code)
		assert.matches("ContourPlot::cpcon", result.message)
	end)

	it("maps ContourPlot3D::ncvb messages to E_NO_ISOSURFACE", function()
		local stderr = [=[Message[ContourPlot3D::ncvb, "Contours"]]=]
		local result = plot.translate_plot_error(1, "", stderr)
		assert.are.equal(error_handler.E_NO_ISOSURFACE, result.code)
		assert.matches("ContourPlot3D::ncvb", result.message)
	end)

	it("falls back to the raw message when no mapping exists", function()
		local stdout = "Generic failure"
		local result = plot.translate_plot_error(2, stdout, "")
		assert.is_nil(result.code)
		assert.are.equal(stdout, result.message)
	end)
end)

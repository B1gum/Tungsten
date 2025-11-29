local mock_utils = require("tests.helpers.mock_utils")

describe("plot backend interface", function()
	before_each(function()
		mock_utils.reset_modules({
			"tungsten.backends.wolfram",
			"tungsten.backends.python",
			"tungsten.backends.wolfram.plot",
			"tungsten.backends.python.plot",
		})
	end)

	it("wolfram backend exposes plot interfaces", function()
		local backend = require("tungsten.backends.wolfram")
		assert.is_function(backend.build_plot_command)
		assert.is_function(backend.plot_async)
		backend.build_plot_command({})
		backend.plot_async({}, function() end)
	end)

	it("python backend exposes plot interfaces", function()
		local backend = require("tungsten.backends.python")
		assert.is_function(backend.build_plot_command)
		assert.is_function(backend.plot_async)
		backend.build_plot_command({})
		backend.plot_async({}, function() end)
	end)
end)

local function reset_modules()
	package.loaded["tungsten.core"] = nil
	package.loaded["tungsten.core.domain_manager"] = nil
	package.loaded["tungsten.core.registry"] = nil
	package.loaded["tungsten.config"] = nil
	package.loaded["tungsten.domains.plotting"] = nil
end

describe("plotting domain registration", function()
	before_each(function()
		reset_modules()
	end)

	it("registers plotting commands when tungsten.core loads", function()
		local registry = require("tungsten.core.registry")
		registry.reset()

		require("tungsten.core")

		local registered = {}
		for _, cmd in ipairs(registry.commands) do
			registered[cmd.name] = true
		end

		assert.is_true(registered.TungstenPlot, "Expected TungstenPlot command to be registered")
		assert.is_true(registered.TungstenPlotParametric, "Expected TungstenPlotParametric command to be registered")
	end)
end)

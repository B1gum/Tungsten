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

		local has_plot_command = false
		for _, cmd in ipairs(registry.commands) do
			if cmd.name == "TungstenPlot" then
				has_plot_command = true
				break
			end
		end
		assert.is_true(has_plot_command, "Expected TungstenPlot command to be registered")
	end)
end)

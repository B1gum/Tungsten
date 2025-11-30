local stub = require("luassert.stub")
local mock_utils = require("tests.helpers.mock_utils")

describe("python handler loader", function()
	local handlers
	local registry
	local logger

	local function reset(declared_domains, priorities)
		mock_utils.reset_modules({
			"tungsten.backends.python.handlers",
			"tungsten.config",
			"tungsten.core.registry",
			"tungsten.util.logger",
			"tungsten.backends.python.domains.arithmetic",
			"tungsten.backends.python.domains.custom",
			"tungsten.backends.python.domains.other",
			"tungsten.backends.python.domains.plotting_handlers",
		})

		registry = mock_utils.mock_module("tungsten.core.registry", {
			reset_handlers = stub.new({}, "reset_handlers"),
			register_handlers = stub.new({}, "register_handlers"),
			get_domain_priority = function(name)
				return priorities and priorities[name] or 0
			end,
		})

		logger = mock_utils.mock_module("tungsten.util.logger", {
			debug = stub.new({}, "debug"),
			info = stub.new({}, "info"),
			warn = stub.new({}, "warn"),
			error = stub.new({}, "error"),
		})

		mock_utils.mock_module("tungsten.config", { domains = declared_domains })
	end

	it("loads configured domains and registers handlers", function()
		reset({ "arithmetic", "custom" }, { arithmetic = 10, custom = 5 })

		mock_utils.mock_module("tungsten.backends.python.domains.arithmetic", {
			handlers = { number = function() end },
		})
		mock_utils.mock_module("tungsten.backends.python.domains.custom", {
			handlers = { variable = function() end },
		})

		handlers = require("tungsten.backends.python.handlers")
		handlers.init_handlers(nil, registry)

		assert.stub(registry.reset_handlers).was.called(1)
		assert.stub(logger.info).was.called()
		local registered = registry.register_handlers.calls[1].vals[1]
		assert.is_function(registered.number)
		assert.is_function(registered.variable)
	end)

	it("prefers higher priorities and warns on conflicts", function()
		reset({ "custom", "other" }, { custom = 0, other = 0 })

		mock_utils.mock_module("tungsten.backends.python.domains.custom", {
			handlers = {
				shared = function()
					return "a"
				end,
			},
		})
		mock_utils.mock_module("tungsten.backends.python.domains.other", {
			handlers = {
				shared = function()
					return "b"
				end,
			},
		})

		handlers = require("tungsten.backends.python.handlers")
		handlers.init_handlers(nil, registry)

		assert.stub(logger.warn).was.called()
		assert.equals("b", registry.register_handlers.calls[1].vals[1].shared())
	end)

	it("supports domain aliases and logs when nothing loads", function()
		reset({ "plotting" })
		mock_utils.mock_module("tungsten.backends.python.domains.plotting_handlers", {})

		handlers = require("tungsten.backends.python.handlers")
		handlers.reload_handlers()

		assert.stub(logger.warn).was.called()
		assert.stub(logger.error).was.called()
	end)
end)

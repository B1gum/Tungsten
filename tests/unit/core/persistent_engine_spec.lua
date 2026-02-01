local stub = require("luassert.stub")
local engine = require("tungsten.core.engine")
local config = require("tungsten.config")
local manager = require("tungsten.backends.manager")
local state = require("tungsten.state")

describe("Engine (Persistence)", function()
	local mock_backend

	before_each(function()
		mock_backend = {
			evaluate_async = stub(),
			evaluate_persistent = stub(),
			ast_to_code = function()
				return "code"
			end,
		}
		stub(manager, "current", mock_backend)
		state.active_backend = "test_backend"
		config.backend_opts = {
			test_backend = {
				persistent = false,
			},
		}
	end)

	after_each(function()
		manager.current:revert()
		state.active_backend = nil
		config.backend_opts = {}
	end)

	it("calls evaluate_async when persistence is disabled", function()
		config.backend_opts.test_backend.persistent = false
		local callback = function() end

		engine.evaluate_async({}, false, callback)

		assert.stub(mock_backend.evaluate_async).was_called()
		assert.stub(mock_backend.evaluate_persistent).was_not_called()
	end)

	it("calls evaluate_persistent when persistence is enabled", function()
		config.backend_opts.test_backend.persistent = true
		local callback = function() end

		engine.evaluate_async({}, false, callback)

		assert.stub(mock_backend.evaluate_persistent).was_called()
		assert.stub(mock_backend.evaluate_async).was_not_called()
	end)

	it("falls back if backend lacks persistent support", function()
		config.backend_opts.test_backend.persistent = true
		mock_backend.evaluate_persistent = nil
		local callback = function() end

		engine.evaluate_async({}, false, callback)

		assert.stub(mock_backend.evaluate_async).was_called()
	end)
end)
